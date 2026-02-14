import SwiftUI
import StoreKit

/// The upgrade screen presenting Starter and Pro subscription options.
struct PaywallView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var storeManager = StoreManager.shared
    @ObservedObject private var entitlementManager = EntitlementManager.shared

    // MARK: - State

    @State private var selectedProductID: String = StoreManager.ProductID.proMonthly
    @State private var isPurchasing: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    // MARK: - Colors

    private let primaryColor = Color(red: 0x5B / 255.0, green: 0x5F / 255.0, blue: 0xE6 / 255.0)
    private let secondaryColor = Color(red: 0x9B / 255.0, green: 0x6F / 255.0, blue: 0xE8 / 255.0)

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    header

                    if entitlementManager.isPaid {
                        alreadySubscribedView
                    } else {
                        comparisonTable
                        planSelector
                        subscribeButton
                        restoreLink
                    }
                }
                .padding(28)
            }
        }
        .frame(width: 440, height: 620)
        .background(
            LinearGradient(
                colors: [
                    primaryColor.opacity(0.05),
                    secondaryColor.opacity(0.03),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .alert("Erreur", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            // Close button
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("Passez au niveau superieur")
                .font(.system(size: 24, weight: .bold))

            Text("Choisissez le plan adapte a vos besoins")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Already Subscribed

    private var alreadySubscribedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Vous etes abonne a \(entitlementManager.currentTier.displayName)")
                .font(.system(size: 16, weight: .semibold))
                .multilineTextAlignment(.center)

            Text("\(entitlementManager.dailyLimit) actions par jour")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Button {
                dismiss()
            } label: {
                Text("Fermer")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 20)
    }

    // MARK: - Comparison Table

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            comparisonRow(feature: "Corrections / jour", free: "10", starter: "50", pro: "500")
            Divider().padding(.horizontal, 12)
            comparisonRow(feature: "Traductions / jour", free: "10", starter: "50", pro: "500")
            Divider().padding(.horizontal, 12)
            comparisonRow(feature: "Langues", free: "4", starter: "Toutes", pro: "Toutes")
            Divider().padding(.horizontal, 12)
            comparisonRow(feature: "Historique", free: "7 jours", starter: "30 jours", pro: "Illimite")
            Divider().padding(.horizontal, 12)
            comparisonRow(feature: "Raccourcis personnalisables", free: nil, starter: nil, pro: "")
            Divider().padding(.horizontal, 12)
            comparisonRow(feature: "Ton et style", free: nil, starter: nil, pro: "")
        }
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func comparisonRow(feature: String, free: String?, starter: String?, pro: String?) -> some View {
        HStack(spacing: 0) {
            Text(feature)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .frame(width: 130, alignment: .leading)

            tierCell(value: free, color: .secondary)
                .frame(maxWidth: .infinity)

            tierCell(value: starter, color: primaryColor)
                .frame(maxWidth: .infinity)

            tierCell(value: pro, color: secondaryColor)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func tierCell(value: String?, color: Color) -> some View {
        if let value {
            if value.isEmpty {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
            } else {
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(color)
            }
        } else {
            Image(systemName: "minus")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
    }

    // MARK: - Plan Selector

    private var planSelector: some View {
        VStack(spacing: 10) {
            // Column headers
            HStack(spacing: 0) {
                Spacer().frame(width: 130)
                Text("Gratuit")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Text("Starter")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(primaryColor)
                    .frame(maxWidth: .infinity)
                Text("Pro")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(secondaryColor)
                    .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 4)

            ForEach(storeManager.products, id: \.id) { product in
                planButton(product: product)
            }
        }
    }

    private func planButton(product: Product) -> some View {
        let isSelected = selectedProductID == product.id
        let isProPlan = product.id == StoreManager.ProductID.proMonthly

        return Button {
            selectedProductID = product.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(isProPlan ? "Poli Pro" : "Poli Starter")
                            .font(.system(size: 14, weight: .semibold))

                        if isProPlan {
                            Text("Populaire")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    LinearGradient(
                                        colors: [primaryColor, secondaryColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                        }
                    }

                    Text(isProPlan ? "500 actions/jour" : "50 actions/jour")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isSelected ? primaryColor : .primary)
                    Text("/ mois")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? primaryColor.opacity(0.08) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? primaryColor : Color.primary.opacity(0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subscribe Button

    private var subscribeButton: some View {
        Button {
            Task { await performPurchase() }
        } label: {
            Group {
                if isPurchasing || storeManager.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else if storeManager.isSyncingWithBackend {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                        Text("Synchronisation...")
                            .font(.system(size: 15, weight: .semibold))
                    }
                } else {
                    Text("S'abonner")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing || storeManager.isLoading || storeManager.isSyncingWithBackend)
    }

    // MARK: - Restore Link

    private var restoreLink: some View {
        Button {
            Task {
                await storeManager.restorePurchases()
            }
        } label: {
            Text("Restaurer les achats")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .underline()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Purchase Logic

    private func performPurchase() async {
        guard AuthManager.shared.isAuthenticated else {
            errorMessage = "Veuillez vous connecter avant de vous abonner."
            showError = true
            return
        }

        guard let product = storeManager.products.first(where: { $0.id == selectedProductID }) else {
            errorMessage = "Produit introuvable. Veuillez reessayer."
            showError = true
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        let success = await storeManager.purchase(product)
        if success {
            // Don't dismiss — the view will automatically switch to
            // alreadySubscribedView since entitlementManager.isPaid is now true.
            NotificationService.shared.send(
                title: "Poli",
                body: "Abonnement active avec succes !"
            )
        }
    }
}

#Preview {
    PaywallView()
}
