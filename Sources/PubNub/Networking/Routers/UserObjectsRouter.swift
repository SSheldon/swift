//
//  UserObjectsRouter.swift
//
//  PubNub Real-time Cloud-Hosted Push API and Push Notification Client Frameworks
//  Copyright © 2019 PubNub Inc.
//  https://www.pubnub.com/
//  https://www.pubnub.com/terms
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

// MARK: - Router

struct UserObjectsRouter: HTTPRouter {
  // Nested Endpoint
  enum Endpoint: CustomStringConvertible {
    case fetchAll(include: CustomIncludeField?, limit: Int?, start: String?, end: String?, count: Bool?)
    case fetch(userID: String, include: CustomIncludeField?)
    case create(user: PubNubUser, include: CustomIncludeField?)
    case update(user: PubNubUser, include: CustomIncludeField?)
    case delete(userID: String)
    case fetchMemberships(
      userID: String,
      include: [CustomIncludeField]?,
      limit: Int?, start: String?, end: String?, count: Bool?
    )
    case modifyMemberships(
      userID: String,
      joining: [ObjectIdentifiable], updating: [ObjectIdentifiable], leaving: [ObjectIdentifiable],
      include: [CustomIncludeField]?,
      limit: Int?, start: String?, end: String?, count: Bool?
    )

    var description: String {
      switch self {
      case .fetchAll:
        return "Fetch All User Objects"
      case .fetch:
        return "Fetch User Object"
      case .create:
        return "Create User Object"
      case .update:
        return "Update User Object"
      case .delete:
        return "Delete User Object"
      case .fetchMemberships:
        return "Fetch User's Memberships"
      case .modifyMemberships:
        return "Modify User's Memberships"
      }
    }
  }

  // Init
  init(_ endpoint: Endpoint, configuration: RouterConfiguration) {
    self.endpoint = endpoint
    self.configuration = configuration
  }

  var endpoint: Endpoint
  var configuration: RouterConfiguration

  // Protocol Properties
  var service: PubNubService {
    return .objects
  }

  var category: String {
    return endpoint.description
  }

  var path: Result<String, Error> {
    let path: String

    switch endpoint {
    case .fetchAll:
      path = "/v1/objects/\(subscribeKey)/users"
    case .fetch(let userID, _):
      path = "/v1/objects/\(subscribeKey)/users/\(userID.urlEncodeSlash)"
    case .create:
      path = "/v1/objects/\(subscribeKey)/users"
    case .update(let user, _):
      path = "/v1/objects/\(subscribeKey)/users/\(user.id.urlEncodeSlash)"
    case let .delete(userID):
      path = "/v1/objects/\(subscribeKey)/users/\(userID.urlEncodeSlash)"
    case let .fetchMemberships(parameters):
      path = "/v1/objects/\(subscribeKey)/users/\(parameters.userID.urlEncodeSlash)/spaces"
    case let .modifyMemberships(parameters):
      path = "/v1/objects/\(subscribeKey)/users/\(parameters.userID.urlEncodeSlash)/spaces"
    }
    return .success(path)
  }

  var queryItems: Result<[URLQueryItem], Error> {
    var query = defaultQueryItems

    switch endpoint {
    case let .fetchAll(include, limit, start, end, count):
      query.appendIfPresent(key: .include, value: include?.rawValue)
      query.appendIfPresent(key: .limit, value: limit?.description)
      query.appendIfPresent(key: .start, value: start?.description)
      query.appendIfPresent(key: .end, value: end?.description)
      query.appendIfPresent(key: .count, value: count?.description)
    case let .fetch(_, include):
      query.appendIfPresent(key: .include, value: include?.rawValue)
    case let .create(_, include):
      query.appendIfPresent(key: .include, value: include?.rawValue)
    case let .update(_, include):
      query.appendIfPresent(key: .include, value: include?.rawValue)
    case .delete:
      break
    case let .fetchMemberships(_, include, limit, start, end, count):
      query.appendIfPresent(key: .include, value: include?.map { $0.rawValue }.csvString)
      query.appendIfPresent(key: .limit, value: limit?.description)
      query.appendIfPresent(key: .start, value: start?.description)
      query.appendIfPresent(key: .end, value: end?.description)
      query.appendIfPresent(key: .count, value: count?.description)
    case let .modifyMemberships(_, _, _, _, include, limit, start, end, count):
      query.appendIfPresent(key: .include, value: include?.map { $0.rawValue }.csvString)
      query.appendIfPresent(key: .limit, value: limit?.description)
      query.appendIfPresent(key: .start, value: start?.description)
      query.appendIfPresent(key: .end, value: end?.description)
      query.appendIfPresent(key: .count, value: count?.description)
    }

    return .success(query)
  }

  var method: HTTPMethod {
    switch endpoint {
    case .fetchAll:
      return .get
    case .fetch:
      return .get
    case .create:
      return .post
    case .update:
      return .patch
    case .delete:
      return .delete
    case .fetchMemberships:
      return .get
    case .modifyMemberships:
      return .patch
    }
  }

  var body: Result<Data?, Error> {
    switch endpoint {
    case .create(let user, _):
      return user.jsonDataResult.map { .some($0) }
    case .update(let user, _):
      return user.jsonDataResult.map { .some($0) }
    case let .modifyMemberships(_, joining, updating, leaving, _, _, _, _, _):
      let changeset = ObjectIdentifiableChangeset(add: joining,
                                                  update: updating,
                                                  remove: leaving)
      return changeset.encodableJSONData.map { .some($0) }
    default:
      return .success(nil)
    }
  }

  var pamVersion: PAMVersionRequirement {
    return .version3
  }

  // Validated
  var validationErrorDetail: String? {
    switch endpoint {
    case .fetchAll:
      return nil
    case .fetch(let userID, _):
      return isInvalidForReason((userID.isEmpty, ErrorDescription.emptyUserID))
    case .create(let user, _):
      return isInvalidForReason((!user.isValid, ErrorDescription.invalidPubNubUser))
    case .update(let user, _):
      return isInvalidForReason((!user.isValid, ErrorDescription.invalidPubNubUser))
    case let .delete(userID):
      return isInvalidForReason((userID.isEmpty, ErrorDescription.emptyUserID))
    case let .fetchMemberships(parameters):
      return isInvalidForReason((parameters.userID.isEmpty, ErrorDescription.emptyUserID))
    case let .modifyMemberships(parameters):
      return isInvalidForReason(
        (parameters.userID.isEmpty, ErrorDescription.emptyUserID),
        (!parameters.joining.allSatisfy { $0.isValid }, ErrorDescription.invalidJoiningMembership),
        (!parameters.updating.allSatisfy { $0.isValid }, ErrorDescription.invalidUpdatingMembership),
        (!parameters.leaving.allSatisfy { $0.isValid }, ErrorDescription.invalidLeavingMembership)
      )
    }
  }
}

// MARK: - Object Protocols

public protocol ObjectIdentifiable: JSONCodable {
  var id: String { get }
  var custom: [String: JSONCodableScalar]? { get }
}

extension ObjectIdentifiable {
  var isValid: Bool {
    return !id.isEmpty
  }

  var identifiableType: SimpleObjectIdentifiable {
    guard let object = self as? SimpleObjectIdentifiable else {
      return SimpleObjectIdentifiable(self)
    }

    return object
  }
}

extension ObjectIdentifiable where Self: Equatable {
  func isEqual(_ other: ObjectIdentifiable?) -> Bool {
    return id == other?.id &&
      custom?.allSatisfy {
        other?.custom?[$0]?.scalarValue == $1.scalarValue
      } ?? true
  }
}

struct SimpleObjectIdentifiable: ObjectIdentifiable, Codable {
  let id: String
  let custom: [String: JSONCodableScalar]?

  init(id: String, custom: [String: JSONCodableScalar]?) {
    self.id = id
    self.custom = custom
  }

  init(_ proto: ObjectIdentifiable) {
    id = proto.id
    custom = proto.custom
  }

  enum CodingKeys: String, CodingKey {
    case id
    case custom
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(String.self, forKey: .id)
    custom = try container.decodeIfPresent([String: JSONCodableScalarType].self, forKey: .custom) ?? [:]
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(id, forKey: .id)
    try container.encode(custom?.mapValues { $0.scalarValue }, forKey: .custom)
  }
}

struct ObjectIdentifiableChangeset: Codable {
  let add: [SimpleObjectIdentifiable]
  let update: [SimpleObjectIdentifiable]
  let remove: [SimpleObjectIdentifiable]

  init(add: [ObjectIdentifiable], update: [ObjectIdentifiable], remove: [ObjectIdentifiable]) {
    self.add = add.map { $0.identifiableType }
    self.update = update.map { $0.identifiableType }
    self.remove = remove.map { $0.identifiableType }
  }
}

// MARK: - User Protocols

public protocol PubNubUser: ObjectIdentifiable {
  var name: String { get }
  var externalId: String? { get }
  var profileURL: String? { get }
  var email: String? { get }
  var custom: [String: JSONCodableScalar]? { get }
}

extension PubNubUser {
  var isValid: Bool {
    return !id.isEmpty && !name.isEmpty
  }

  var userObject: UserObject {
    guard let object = self as? UserObject else {
      return UserObject(self)
    }
    return object
  }
}

extension PubNubUser where Self: Equatable {
  func isEqual(_ other: PubNubUser?) -> Bool {
    return id == other?.id &&
      name == other?.name &&
      externalId == other?.externalId &&
      profileURL == other?.profileURL &&
      email == other?.email &&
      custom?.allSatisfy {
        other?.custom?[$0]?.scalarValue == $1.scalarValue
      } ?? true
  }
}

public protocol UpdatableUser: PubNubUser {
  var updated: Date { get }
  var eTag: String { get }
}

extension UpdatableUser {
  var userObject: UserObject {
    guard let object = self as? UserObject else {
      return UserObject(updatable: self)
    }
    return object
  }
}

// MARK: - Response Decoder

struct UserObjectResponseDecoder: ResponseDecoder {
  typealias Payload = UserObjectResponsePayload
}

struct UserObjectsResponseDecoder: ResponseDecoder {
  typealias Payload = UserObjectsResponsePayload
}

struct UserSpacesResponseDecoder: ResponseDecoder {
  typealias Payload = UserObjectsResponsePayload
}

// MARK: - Membership Response Decoder

struct UserMembershipsObjectsResponseDecoder: ResponseDecoder {
  typealias Payload = UserMembershipsResponsePayload
}

// MARK: - Response

public struct UserObject: Codable, Equatable, UpdatableUser {
  public let id: String
  public let name: String
  public let externalId: String?
  public let profileURL: String?
  public let email: String?
  public let created: Date
  public let updated: Date
  public let eTag: String

  public var custom: [String: JSONCodableScalar]? {
    return customType
  }

  let customType: [String: JSONCodableScalarType]?

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case externalId
    case profileURL
    case email
    case customType = "custom"
    case created
    case updated
    case eTag
  }

  public init(
    name: String,
    id: String? = nil,
    externalId: String? = nil,
    profileURL: String? = nil,
    email: String? = nil,
    custom: [String: JSONCodableScalar]? = nil,
    created: Date = Date.distantPast,
    updated: Date? = nil,
    eTag: String = ""
  ) {
    self.id = id ?? name
    self.name = name
    self.email = email
    self.externalId = externalId
    self.profileURL = profileURL
    customType = custom?.mapValues { $0.scalarValue }
    self.created = created
    self.updated = updated ?? created
    self.eTag = eTag
  }

  public init(_ userProto: PubNubUser) {
    self.init(
      name: userProto.name,
      id: userProto.id,
      externalId: userProto.externalId,
      profileURL: userProto.profileURL,
      email: userProto.email,
      custom: userProto.custom
    )
  }

  public init(updatable: UpdatableUser) {
    self.init(
      name: updatable.name,
      id: updatable.id,
      externalId: updatable.externalId,
      profileURL: updatable.profileURL,
      email: updatable.email,
      custom: updatable.custom,
      updated: updatable.updated,
      eTag: updatable.eTag
    )
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    email = try container.decodeIfPresent(String.self, forKey: .email)
    externalId = try container.decodeIfPresent(String.self, forKey: .externalId)
    profileURL = try container.decodeIfPresent(String.self, forKey: .profileURL)
    customType = try container.decodeIfPresent([String: JSONCodableScalarType].self, forKey: .customType)
    created = try container.decodeIfPresent(Date.self, forKey: .created) ?? Date.distantPast
    updated = try container.decode(Date.self, forKey: .updated)
    eTag = try container.decode(String.self, forKey: .eTag)
  }
}

public struct UserObjectResponsePayload: Codable {
  public let status: Int
  public let user: UserObject

  enum CodingKeys: String, CodingKey {
    case status
    case user = "data"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    status = try container.decode(Int.self, forKey: .status)
    user = try container.decode(UserObject.self, forKey: .user)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(status, forKey: .status)
    try container.encode(user.codableValue, forKey: .user)
  }
}

public struct UserObjectsResponsePayload: Codable {
  public let status: Int
  public let users: [UserObject]
  public let totalCount: Int?
  public let next: String?
  public let prev: String?

  enum CodingKeys: String, CodingKey {
    case status
    case users = "data"
    case totalCount
    case next
    case prev
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    status = try container.decode(Int.self, forKey: .status)
    users = try container.decode([UserObject].self, forKey: .users)
    totalCount = try container.decodeIfPresent(Int.self, forKey: .totalCount)
    next = try container.decodeIfPresent(String.self, forKey: .next)
    prev = try container.decodeIfPresent(String.self, forKey: .prev)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(status, forKey: .status)
    try container.encode(users.codableValue, forKey: .users)
    try container.encode(totalCount, forKey: .totalCount)
    try container.encode(next, forKey: .next)
    try container.encode(prev, forKey: .prev)
  }
}

// MARK: - Membership Response

public struct SpaceMembership: Codable, Equatable {
  public let id: String
  public let customType: [String: JSONCodableScalarType]
  public let space: SpaceObject?
  public let created: Date
  public let updated: Date
  public let eTag: String

  enum CodingKeys: String, CodingKey {
    case id
    case space
    case customType = "custom"
    case created
    case updated
    case eTag
  }

  public init(
    id: String,
    custom: [String: JSONCodableScalar] = [:],
    space: PubNubSpace?,
    created: Date = Date(),
    updated: Date? = nil,
    eTag: String = ""
  ) {
    self.id = id
    customType = custom.mapValues { $0.scalarValue }
    self.space = space?.spaceObject
    self.created = created
    self.updated = updated ?? created
    self.eTag = eTag
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(String.self, forKey: .id)
    space = try container.decodeIfPresent(SpaceObject.self, forKey: .space)
    customType = try container.decodeIfPresent([String: JSONCodableScalarType].self, forKey: .customType) ?? [:]
    created = try container.decode(Date.self, forKey: .created)
    updated = try container.decode(Date.self, forKey: .updated)
    eTag = try container.decode(String.self, forKey: .eTag)
  }
}

public struct UserMembershipsResponsePayload: Codable {
  public let status: Int
  public let memberships: [SpaceMembership]
  public let totalCount: Int?
  public let next: String?
  public let prev: String?

  enum CodingKeys: String, CodingKey {
    case status
    case memberships = "data"
    case totalCount
    case next
    case prev
  }

  // swiftlint:disable:next file_length
}