//
//  LocalEventRepository.swift
//  Dangle
//
//  Created by Jae hyuk Yim on 2023/08/24.
//

import Foundation

protocol LocalEventRepository {
    func newIssueParsing(
        category: String,
        completion: @escaping (Result<NewIssue, Error>) -> Void)

    func culturalEventParsing(
        location: String,
        completion: @escaping (Result<CulturalEvent, Error>) -> Void)

    func educationEventParsing(
        location: String,
        completion: @escaping (Result<EducationEvent, Error>) -> Void)
}
