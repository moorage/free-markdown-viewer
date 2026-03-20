import Foundation

struct HarnessCommandRequest: Codable {
    let id: String
    let command: String
    let arguments: [String: String]?
}

struct HarnessCommandResponse: Codable {
    let id: String
    let status: String
    let result: [String: String]?
    let error: String?
}
