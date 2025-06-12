import Foundation

func filterByTime(_ item: MediaItem, timePref: String) -> Bool {
    switch timePref {
    case "under_1h":
        return item.duration <= 60
    case "1_2h":
        return item.duration > 60 && item.duration <= 125
    case "2plus":
        return item.duration > 125
    default:
        return true
    }
}

func filterByFormat(_ item: MediaItem, format: String) -> Bool {
    return format == "any" || item.type == format
} 