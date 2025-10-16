import Foundation
import SwiftUI

enum SampleData {
    static let projectAttachment = ChatAttachment(
        name: "Projektplan.pdf",
        size: 1_024_000,
        type: "application/pdf",
        kind: .file
    )

    static let audioAttachment = ChatAttachment(
        name: "Feedback.m4a",
        size: 420_000,
        type: "audio/m4a",
        kind: .audio,
        durationSeconds: 42
    )

    static let welcomeMessage = ChatMessage(
        author: .agent,
        content: "Hallo! Ich bin dein AITI Explorer Agent. Wie kann ich dir heute helfen?",
        timestamp: Date().addingTimeInterval(-3600),
        attachments: []
    )

    static let followUpMessage = ChatMessage(
        author: .user,
        content: "Ich brauche Unterstützung bei der Planung einer Launch-Kampagne.",
        timestamp: Date().addingTimeInterval(-3400),
        attachments: [projectAttachment]
    )

    static let agentResponse = ChatMessage(
        author: .agent,
        content: "Sehr gern! Ich schlage vor, dass wir mit einer Zielgruppenanalyse starten. Soll ich dir dafür ein Template vorbereiten?",
        timestamp: Date().addingTimeInterval(-3200),
        attachments: []
    )

    static func conversation(agentId: UUID, title: String) -> Conversation {
        Conversation(
            agentId: agentId,
            title: title,
            lastUpdated: Date(),
            messages: [welcomeMessage, followUpMessage, agentResponse]
        )
    }

    static var marketingAgent: AgentProfile {
        let id = UUID()
        return AgentProfile(
            id: id,
            name: "Explorer Marketing",
            role: "Kampagnen-Spezialist",
            description: "Unterstützt dich bei der Planung deiner Marketing-Aktivitäten.",
            status: .online,
            avatarSystemName: "megaphone.fill",
            conversation: conversation(agentId: id, title: "Launch Kampagne"),
            webhookURL: URL(string: "https://hooks.aiti.ai/marketing")
        )
    }

    static var productAgent: AgentProfile {
        let id = UUID()
        return AgentProfile(
            id: id,
            name: "Explorer Produkt",
            role: "Produktmanager",
            description: "Analysiert Anforderungen und erstellt User Stories.",
            status: .online,
            avatarSystemName: "shippingbox.fill",
            conversation: conversation(agentId: id, title: "Feature Discovery"),
            webhookURL: URL(string: "https://hooks.aiti.ai/product")
        )
    }

    static var researchAgent: AgentProfile {
        let id = UUID()
        return AgentProfile(
            id: id,
            name: "Explorer Research",
            role: "Research Analyst",
            description: "Findet Antworten und fasst Ergebnisse prägnant zusammen.",
            status: .online,
            avatarSystemName: "chart.bar.fill",
            conversation: conversation(agentId: id, title: "Marktanalyse"),
            webhookURL: URL(string: "https://hooks.aiti.ai/research")
        )
    }

    static var previewUser: UserProfile {
        UserProfile(
            name: "Alex Example",
            email: "demo@aiti.ai",
            bio: "Leitet AI-gestützte Innovationsprojekte im Team.",
            avatarSystemName: "person.crop.circle.fill.badge.checkmark",
            isActive: true,
            agents: [marketingAgent, productAgent, researchAgent]
        )
    }

    static var demoCredentials: UserCredentials {
        UserCredentials(
            email: "demo@aiti.ai",
            password: "SwiftRocks!",
            profile: previewUser
        )
    }

    static var defaultSettings: AgentSettingsModel {
        if let stored = loadSettings() {
            return stored
        }
        return AgentSettingsModel(
            colorScheme: .system,
            accentColor: .gold,
            playSendSound: true,
            notes: "Passe Layout und Verhalten deiner App nach deinen Vorlieben an."
        )
    }

    private static let settingsKey = "aiti.settings"

    private static func loadSettings() -> AgentSettingsModel? {
        guard let data = UserDefaults.standard.data(forKey: settingsKey) else {
            return nil
        }

        return try? JSONDecoder().decode(AgentSettingsModel.self, from: data)
    }

    static func saveSettings(_ settings: AgentSettingsModel) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }
}
