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

                    if entitlementManager.isCancelledButActive {
                        cancelledButActiveView
                    } else if entitlementManager.isPaid {
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
        .alert(String(localized: "paywall.error"), isPresented: $showError) {
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
                .focusable(false)
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

            Text("paywall.title")
                .font(.system(size: 24, weight: .bold))

            Text("paywall.subtitle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Cancelled But Active

    private var cancelledButActiveView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text("paywall.cancelled_active.title")
                .font(.system(size: 16, weight: .semibold))
                .multilineTextAlignment(.center)

            if let expiresFormatted = entitlementManager.expiresAtFormatted {
                Text(String(format: String(localized: "paywall.cancelled_active.message"), expiresFormatted))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            comparisonTable
            planSelector
            subscribeButton
            restoreLink
        }
    }

    // MARK: - Already Subscribed

    private var alreadySubscribedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text(String(format: String(localized: "paywall.subscribed"), entitlementManager.currentTier.displayName))
                .font(.system(size: 16, weight: .semibold))
                .multilineTextAlignment(.center)

            Text(entitlementManager.currentTier.isPaid
                 ? String(format: String(localized: "paywall.actions_per_day"), entitlementManager.currentTier.usageLimit)
                 : String(format: String(localized: "paywall.actions_total"), entitlementManager.currentTier.usageLimit))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Button {
                dismiss()
            } label: {
                Text("paywall.close")
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
            .focusable(false)
        }
        .padding(.top, 20)
    }

    // MARK: - Comparison Table

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            comparisonRow(feature: String(localized: "paywall.table.corrections"), free: String(localized: "paywall.table.free_10_total"), starter: String(localized: "paywall.table.50_per_day"), pro: String(localized: "paywall.table.500_per_day"))
            Divider().padding(.horizontal, 12)
            comparisonRow(feature: String(localized: "paywall.table.translations"), free: String(localized: "paywall.table.free_10_total"), starter: String(localized: "paywall.table.50_per_day"), pro: String(localized: "paywall.table.500_per_day"))
            Divider().padding(.horizontal, 12)
            comparisonRow(feature: String(localized: "paywall.table.languages"), free: String(localized: "paywall.table.4_languages"), starter: String(localized: "paywall.table.all_languages"), pro: String(localized: "paywall.table.all_languages"))
            Divider().padding(.horizontal, 12)
            comparisonRow(feature: String(localized: "paywall.table.history"), free: String(localized: "paywall.table.7_days"), starter: String(localized: "paywall.table.30_days"), pro: String(localized: "paywall.table.unlimited"))
            Divider().padding(.horizontal, 12)
            comparisonRow(feature: String(localized: "paywall.table.custom_shortcuts"), free: nil, starter: nil, pro: "")
            Divider().padding(.horizontal, 12)
            comparisonRow(feature: String(localized: "paywall.table.tone_style"), free: nil, starter: nil, pro: "")
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
                Text("paywall.tier.free")
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
                            Text("paywall.popular")
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

                    Text(isProPlan
                         ? String(localized: "paywall.actions_500_day")
                         : String(localized: "paywall.actions_50_day"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isSelected ? primaryColor : .primary)
                    Text("paywall.per_month")
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
        .focusable(false)
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
                        Text("paywall.syncing")
                            .font(.system(size: 15, weight: .semibold))
                    }
                } else {
                    Text("paywall.subscribe")
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
        .focusable(false)
        .disabled(isPurchasing || storeManager.isLoading || storeManager.isSyncingWithBackend)
    }

    // MARK: - Restore Link

    private var restoreLink: some View {
        Button {
            Task {
                await storeManager.restorePurchases()
            }
        } label: {
            Text("paywall.restore")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .underline()
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    // MARK: - Purchase Logic

    private func performPurchase() async {
        guard AuthManager.shared.isAuthenticated else {
            errorMessage = String(localized: "paywall.error.login_first")
            showError = true
            return
        }

        guard let product = storeManager.products.first(where: { $0.id == selectedProductID }) else {
            errorMessage = String(localized: "paywall.error.product_not_found")
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
                body: String(localized: "paywall.subscription_success")
            )
        }
    }
}

#Preview {
    PaywallView()
}
