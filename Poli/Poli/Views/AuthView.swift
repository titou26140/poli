import SwiftUI

/// Combined login / register view displayed in the popover when the user
/// is not authenticated.
struct AuthView: View {

    // MARK: - State

    @ObservedObject private var authManager = AuthManager.shared

    @State private var mode: Mode = .login

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var passwordConfirmation: String = ""

    @FocusState private var focusedField: Field?

    // MARK: - Enums

    enum Mode {
        case login
        case register
    }

    enum Field: Hashable {
        case name, email, password, passwordConfirmation
    }

    // MARK: - Colors

    private let primaryColor = Color(red: 0x5B / 255.0, green: 0x5F / 255.0, blue: 0xE6 / 255.0)
    private let secondaryColor = Color(red: 0x9B / 255.0, green: 0x6F / 255.0, blue: 0xE8 / 255.0)

    // MARK: - Validation

    private var isFormValid: Bool {
        switch mode {
        case .login:
            return !email.isEmpty && !password.isEmpty
        case .register:
            return !name.isEmpty && !email.isEmpty && !password.isEmpty
                && password == passwordConfirmation
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    formFields
                    if let error = authManager.errorMessage {
                        errorBanner(message: error)
                    }
                    submitButton
                    toggleModeLink
                }
                .padding(28)
            }
        }
        .frame(width: 360, height: 480)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(mode == .login ? "Connexion" : "Creer un compte")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [primaryColor, secondaryColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text(mode == .login
                 ? "Connectez-vous pour utiliser Poli"
                 : "Inscrivez-vous pour commencer")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Form Fields

    private var formFields: some View {
        VStack(spacing: 12) {
            if mode == .register {
                TextField("Nom", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)
                    .focused($focusedField, equals: .name)
                    .onSubmit { focusedField = .email }
            }

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .focused($focusedField, equals: .email)
                .onSubmit { focusedField = .password }

            SecureField("Mot de passe", text: $password)
                .textFieldStyle(.roundedBorder)
                .textContentType(mode == .login ? .password : .newPassword)
                .focused($focusedField, equals: .password)
                .onSubmit {
                    if mode == .register {
                        focusedField = .passwordConfirmation
                    } else if isFormValid {
                        submit()
                    }
                }

            if mode == .register {
                SecureField("Confirmer le mot de passe", text: $passwordConfirmation)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .passwordConfirmation)
                    .onSubmit {
                        if isFormValid { submit() }
                    }

                if !password.isEmpty && !passwordConfirmation.isEmpty
                    && password != passwordConfirmation {
                    Text("Les mots de passe ne correspondent pas")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.red)

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.red)
                .multilineTextAlignment(.leading)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            submit()
        } label: {
            Group {
                if authManager.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Text(mode == .login ? "Se connecter" : "S'inscrire")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: isFormValid ? [primaryColor, secondaryColor] : [.gray.opacity(0.5), .gray.opacity(0.5)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!isFormValid || authManager.isLoading)
    }

    // MARK: - Toggle Mode

    private var toggleModeLink: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                mode = mode == .login ? .register : .login
                authManager.errorMessage = nil
                clearFields()
            }
        } label: {
            Text(mode == .login ? "Pas encore de compte ? S'inscrire" : "Deja un compte ? Se connecter")
                .font(.system(size: 12))
                .foregroundStyle(primaryColor)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func submit() {
        Task {
            switch mode {
            case .login:
                await authManager.login(email: email, password: password)
            case .register:
                await authManager.register(
                    name: name,
                    email: email,
                    password: password,
                    passwordConfirmation: passwordConfirmation
                )
            }
        }
    }

    private func clearFields() {
        name = ""
        email = ""
        password = ""
        passwordConfirmation = ""
    }
}

#Preview {
    AuthView()
        .frame(width: 360, height: 480)
}
