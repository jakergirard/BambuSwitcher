import Foundation

struct Configuration: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: URL
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Configuration, rhs: Configuration) -> Bool {
        lhs.id == rhs.id
    }
} 
