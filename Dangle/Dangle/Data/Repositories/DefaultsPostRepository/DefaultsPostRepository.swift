//
//  DefaultPostRepository.swift
//  Dangle
//
//  Created by Jae hyuk Yim on 2023/09/01.
//

import Combine
import CoreLocation
import Foundation
import Firebase
import FirebaseStorage

class DefaultPostRepository: PostRepository {

    let database = Firestore.firestore()
    let storage = Storage.storage()

    private let networkManager: NetworkService
    private let geocodeManager: GeocodingManager
    private var subscriptions = Set<AnyCancellable>()

    private let firestore: Firestore

    init(networkManager: NetworkService, geocodeManager: GeocodingManager, firestore: Firestore) {
        self.networkManager = networkManager
        self.geocodeManager = geocodeManager
        self.firestore = firestore
    }

    // MARK: - 주소 검색
    func searchLocation(
        query: String,
        longitude: String,
        latitude: String,
        radius: Int,
        completion: @escaping (Result<KeywordSearchResult, Error>) -> Void
    ) {
        let params = [
            "query": "\(query)",
            "x": "\(longitude)",
            "y": "\(latitude)",
            "radius": "\(radius)"
        ]

        let resource: Resource<KeywordSearchResult> = Resource(
            base: geocodeManager.keywordSearchBaseURL,
            path: "",
            params: params,
            header: ["Authorization": "KakaoAK \(geocodeManager.restAPIKey)"]
        )

        networkManager.load(resource)
            .receive(on: RunLoop.main)
            .sink { completion in
                switch completion {
                case .failure(let error):
                    print("--> 쿼리를 통해 지오코딩 데이터를 가져오는데 실패했습니다: \(error)")
                case .finished:
                    print("--> 쿼리릍 통해 지오코딩 데이터를 가져왔습니다.")
                }
            } receiveValue: { items in
                completion(.success(items))
            }.store(in: &subscriptions)

    }

    // 카테고리에 따른 Firestore 컬렉션 참조를 가져오는 도움 함수
    private func getCollectionReference(for category: PostCategory) -> CollectionReference {
        return firestore.collection(category.rawValue)
    }

    // Post와 관련된 Firestore 문서 참조를 가져오는 도움 함수
    private func getDocumentReference(for post: Post, in category: PostCategory) -> DocumentReference {
        let collectionRef = getCollectionReference(for: category)
        return collectionRef.document(post.storeName).collection("UserReviews").document(post.authorUID)
    }

    // MARK: - 리뷰 저장
    func addPost(_ post: Post, image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        let imageReference = storage.reference().child("postImages/\(UUID().uuidString).jpg")
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            imageReference.putData(imageData, metadata: nil) { _, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                imageReference.downloadURL { url, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    var updatedPost = post
                    updatedPost.postImage = url?.absoluteString

                    do {
                        let categoryName = post.category.rawValue
                        let categoryCollection = self.firestore.collection(categoryName)
                        let storeRef = categoryCollection.document(post.storeName)
                        let userDocRef = storeRef.collection("UserReviews").document(post.authorUID)
                        try userDocRef.setData(from: updatedPost) { error in
                            if let error = error {
                                completion(.failure(error))
                            } else {
                                completion(.success(()))
                            }
                        }
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        } else {
            completion(.failure(NSError(domain: "Image Data Error", code: 0, userInfo: nil)))
        }
    }

    // MARK: - Map 중심 위치에 따라, 데이터 가져오기 (카테고리 별로)
    func fetchPostsAroundCoordinate(
        category: PostCategory,
        coordinate: CLLocationCoordinate2D,
        radiusInKilometers: Double, // 반경을 km 단위로 받음
        completion: @escaping (Result<[Post], Error>) -> Void
    ) {
        // 중심 좌표를 기반으로 GeoPoint를 생성
        let centerGeoPoint = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)

        // 위도 1도와 경도 1도의 크기 (약 111km)
        let degreesLatitudeInKilometers: Double = 110.574
            let degreesLongitudeInKilometers: Double = 111.32 * cos(coordinate.latitude * .pi / 180.0)


        // 반경을 기반으로 실제 위도 및 경도의 변화량을 계산
        let latOffset = radiusInKilometers / degreesLatitudeInKilometers
        let lonOffset = radiusInKilometers / degreesLongitudeInKilometers

        // 쿼리 범위 계산
        let southWest = GeoPoint(latitude: centerGeoPoint.latitude - latOffset, longitude: centerGeoPoint.longitude - lonOffset)
        let northEast = GeoPoint(latitude: centerGeoPoint.latitude + latOffset, longitude: centerGeoPoint.longitude + lonOffset)

        // Firestore 쿼리 작성
        let query = database.collectionGroup("UserReviews")
            .whereField("category", isEqualTo: category.rawValue)
            .whereField("location", isGreaterThan: southWest)
            .whereField("location", isLessThan: northEast)

        var posts: [Post] = []

        // 디버그 출력: 쿼리 범위 확인 (km로 환산)
        print("Querying data within the following range (in kilometers):")
        print("Latitude: \(radiusInKilometers) km")
        print("Longitude: \(radiusInKilometers) km")

        query.getDocuments { (snapshot, error) in
            if let error = error {
                completion(.failure(error))
                return
            }

            for document in snapshot!.documents {
                if let post = try? document.data(as: Post.self) {
                    posts.append(post)
                }
            }

            completion(.success(posts))
        }
    }

    // MARK: - 해당 점포의 리뷰 가져오기
    func fetchPostsStore(
        storeName: String,
        category: PostCategory,
        completion: @escaping (Result<[Post], Error>) -> Void
    ) {
        var posts: [Post] = []
        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        let query = database.collectionGroup("UserReviews")
            .whereField("category", isEqualTo: category.rawValue) // 카테고리 별로 필터링
            .whereField("storeName", isEqualTo: storeName)

            query.getDocuments { querySnapshot, error in
                if let error = error {
                    completion(.failure(error))
                    dispatchGroup.leave()
                    return
                }

                for document in querySnapshot!.documents {
                    if let post = try? document.data(as: Post.self) {
                        posts.append(post)
                    }
                }
                dispatchGroup.leave()
            }
        // 모든 쿼리가 완료될 때까지 기다린 후, 넘김
        dispatchGroup.notify(queue: .main) {
            completion(.success(posts))
            print("쿼리릍 통해 불러온 posts : \(posts)")
        }
    }

    // MARK: - 작성한 Post 업데이트
    func updatePost(_ post: Post, in category: PostCategory, completion: @escaping (Result<Void, Error>) -> Void) {
         let documentRef = getDocumentReference(for: post, in: category)

         do {
             try documentRef.setData(from: post) { error in
                 if let error = error {
                     completion(.failure(error))
                 } else {
                     completion(.success(()))
                 }
             }
         } catch {
             completion(.failure(error))
         }
     }

    // MARK: - 작성한 Post 삭제
    func deletePost(_ post: Post, in category: PostCategory, completion: @escaping (Result<Void, Error>) -> Void) {
        let documentRef = getDocumentReference(for: post, in: category)

        documentRef.delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}
