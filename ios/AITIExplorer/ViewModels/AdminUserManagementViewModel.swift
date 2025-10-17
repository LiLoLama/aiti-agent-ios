import Foundation
import Combine

@MainActor
final class AdminUserManagementViewModel: ObservableObject {
    @Published private(set) var users: [UserProfile] = []
    @Published var isLoading = false
    @Published var alertMessage: String?
    @Published private(set) var updatingUserIDs: Set<UUID> = []

    private weak var appState: AppState?

    func attach(appState: AppState) {
        self.appState = appState
    }

    func loadUsersIfNeeded() {
        guard users.isEmpty else { return }
        loadUsers()
    }

    func loadUsers() {
        Task { await refresh() }
    }

    func refresh() async {
        guard let appState else { return }
        isLoading = true
        alertMessage = nil

        do {
            let fetched = try await appState.fetchAllUsers()
            users = sortProfiles(fetched)
            isLoading = false
        } catch {
            alertMessage = error.localizedDescription
            isLoading = false
        }
    }

    func toggleActivation(for user: UserProfile) {
        setUser(user, isActive: !user.isActive)
    }

    func setUser(_ user: UserProfile, isActive: Bool) {
        guard let appState, let index = users.firstIndex(where: { $0.id == user.id }) else { return }

        let previousValue = users[index].isActive
        users[index].isActive = isActive
        updatingUserIDs.insert(user.id)

        Task { [weak self] in
            guard let self else { return }

            do {
                try await appState.updateUserStatus(userId: user.id, isActive: isActive)
            } catch {
                await MainActor.run {
                    if let revertIndex = self.users.firstIndex(where: { $0.id == user.id }) {
                        self.users[revertIndex].isActive = previousValue
                    }
                    self.alertMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                self.updatingUserIDs.remove(user.id)
            }
        }
    }

    func isUpdating(userId: UUID) -> Bool {
        updatingUserIDs.contains(userId)
    }

    private func sortProfiles(_ profiles: [UserProfile]) -> [UserProfile] {
        profiles.sorted { lhs, rhs in
            let left = lhs.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let right = rhs.name.trimmingCharacters(in: .whitespacesAndNewlines)

            if left.isEmpty && right.isEmpty {
                return lhs.email.localizedCaseInsensitiveCompare(rhs.email) == .orderedAscending
            }

            if left.isEmpty {
                return false
            }

            if right.isEmpty {
                return true
            }

            return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
        }
    }
}
