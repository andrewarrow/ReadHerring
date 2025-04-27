import SwiftUI

struct CastFilter: Equatable {
    var gender: String = "M"
    var age: String = "none"
    var race: String = "none"
    var emotion: String = "none"
    
    static let ageOptions = ["none", "1-21", "21-35", "34-50", "49-100"]
    static let raceOptions = ["none", "asian", "white", "latino_hispanic", "middle_eastern", "indian", "black"]
    static let emotionOptions = ["none", "happy", "neutral"]
    static let genderOptions = ["M", "F", "random"]
}