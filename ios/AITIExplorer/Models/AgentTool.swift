import Foundation

enum AgentTool: String, CaseIterable, Identifiable, Codable, Hashable {
    case webSearch
    case dataAnalysis
    case automation
    case webhook

    var id: String { rawValue }

    var title: String {
        switch self {
        case .webSearch:
            return "Websuche"
        case .dataAnalysis:
            return "Datenanalyse"
        case .automation:
            return "Automationen"
        case .webhook:
            return "Webhook"
        }
    }

    var description: String {
        switch self {
        case .webSearch:
            return "Findet aktuelle Informationen und Quellen im Web."
        case .dataAnalysis:
            return "Analysiert Dateien und strukturiert Daten."
        case .automation:
            return "Führt wiederkehrende Prozesse automatisiert aus."
        case .webhook:
            return "Kann externe Dienste über Webhooks ansprechen."
        }
    }

    var iconName: String {
        switch self {
        case .webSearch:
            return "magnifyingglass"
        case .dataAnalysis:
            return "chart.bar"
        case .automation:
            return "gearshape.2"
        case .webhook:
            return "arrow.triangle.2.circlepath"
        }
    }
}
