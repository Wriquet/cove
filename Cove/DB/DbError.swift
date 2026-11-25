import Foundation

enum DbError: Error, LocalizedError {
    case connection(String)
    case query(String)
    case invalidPath(expected: Int, got: Int)
    case other(String)

    var errorDescription: String? {
        switch self {
        case .connection(let msg): L10n.format("connection failed: %@", msg)
        case .query(let msg): L10n.format("query failed: %@", msg)
        case .invalidPath(let expected, let got): L10n.format("invalid path: expected %lld segments, got %lld", Int64(expected), Int64(got))
        case .other(let msg): msg
        }
    }
}
