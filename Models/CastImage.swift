import SwiftUI

struct CastImage: Identifiable, Hashable {
    var id = UUID()
    var imageName: String
    var race: String
    var age: String
    var gender: String
    var emotion: String
    
    static func parseFromFolder(folderName: String) -> CastImage? {
        // Format: race_age_gender_emotion
        let components = folderName.split(separator: "_")
        guard components.count == 4 else { return nil }
        
        let race = String(components[0])
        let age = String(components[1])
        let gender = String(components[2])
        let emotion = String(components[3])
        
        return CastImage(
            imageName: folderName,
            race: race,
            age: age,
            gender: gender,
            emotion: emotion
        )
    }
    
    func matchesFilter(filter: CastFilter) -> Bool {
        if filter.gender != "random" && gender != filter.gender {
            return false
        }
        
        if filter.age != "none" && age != filter.age {
            return false
        }
        
        if filter.race != "none" && race != filter.race {
            return false
        }
        
        if filter.emotion != "none" && emotion != filter.emotion {
            return false
        }
        
        return true
    }
}