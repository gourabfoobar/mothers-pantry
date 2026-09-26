import SwiftUI

/// Canvas 3.2 "Address & recipient". Handles the empty-state (no saved
/// address/recipient yet) inline rather than as a separate sub-flow, since
/// the canvas doesn't spec a dedicated "add address" screen.
struct AddressView: View {
    @Binding var path: [AppRoute]

    @State private var addresses: [DeliveryAddress] = []
    @State private var recipients: [Recipient] = []
    @State private var selectedAddressId: String?
    @State private var mayCall = true
    @State private var isAddingAddress = false
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    @State private var newLabel = "Ma's home"
    @State private var newLine1 = ""
    @State private var newCity = ""
    @State private var newPincode = ""
    @State private var recipientName = "Ma"
    @State private var recipientPhone = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(label: "1 / 3") { path.safePop() }

                    Text("Where should it go?")
                        .font(.mono(26, weight: .semibold))
                        .foregroundStyle(Theme.ink)

                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
                    } else {
                        addressSection
                        recipientSection
                    }

                    if let errorMessage {
                        Text(errorMessage).font(.mono(13)).foregroundStyle(Theme.accentText)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 54)
                .padding(.bottom, 24)
            }

            VStack(spacing: 12) {
                Button {
                    save()
                } label: {
                    if isSaving { ProgressView().tint(Theme.background) } else { Text("Confirm & continue") }
                }
                .buttonStyle(.pantryPrimary(enabled: canContinue))
                .disabled(!canContinue || isSaving)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 16)
        }
        .background(Theme.background)
        .navigationBarHidden(true)
        .task { await load() }
    }

    private var canContinue: Bool {
        if isAddingAddress || addresses.isEmpty {
            return !newLine1.trimmingCharacters(in: .whitespaces).isEmpty && !recipientNameOrExisting.isEmpty
        }
        return selectedAddressId != nil
    }

    private var recipientNameOrExisting: String {
        recipients.first?.name ?? recipientName
    }

    @ViewBuilder private var addressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(addresses) { address in
                addressRow(address)
            }

            if isAddingAddress || addresses.isEmpty {
                addAddressForm
            } else {
                Button {
                    isAddingAddress = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                        Text("Add a new address")
                    }
                    .font(.mono(15))
                    .foregroundStyle(Theme.ink)
                }
                .padding(.vertical, 12)
            }
        }
    }

    private func addressRow(_ address: DeliveryAddress) -> some View {
        Button {
            selectedAddressId = address.id
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(Theme.accentText)
                VStack(alignment: .leading, spacing: 3) {
                    Text(address.label).font(.mono(16, weight: .medium)).foregroundStyle(Theme.ink)
                    Text([address.line1, address.city, address.pincode].compactMap { $0 }.joined(separator: ", "))
                        .font(.mono(13)).foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Circle()
                    .strokeBorder(selectedAddressId == address.id ? Theme.ink : Theme.border, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().fill(Theme.ink).frame(width: 12, height: 12).opacity(selectedAddressId == address.id ? 1 : 0))
            }
            .padding(16)
            .background(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(selectedAddressId == address.id ? Theme.ink : Theme.border, lineWidth: selectedAddressId == address.id ? 1.5 : 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        }
        .buttonStyle(.plain)
    }

    private var addAddressForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            labeledField("Label", text: $newLabel, placeholder: "Ma's home")
            labeledField("Address", text: $newLine1, placeholder: "12B Hindusthan Park")
            HStack(spacing: 10) {
                labeledField("City", text: $newCity, placeholder: "Kolkata")
                labeledField("Pincode", text: $newPincode, placeholder: "700029")
            }
        }
        .padding(16)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
    }

    @ViewBuilder private var recipientSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECIPIENT").font(.mono(13)).tracking(1).foregroundStyle(Theme.secondaryText)

            if let recipient = recipients.first {
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        Circle().fill(Theme.paleAccent).frame(width: 40, height: 40)
                            .overlay(Text(String(recipient.name.first ?? "?")).font(.mono(18, weight: .bold)).foregroundStyle(Theme.accent))
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(recipient.name).font(.mono(16, weight: .medium)).foregroundStyle(Theme.ink)
                                if let relation = recipient.relation {
                                    Text("· \(relation)").font(.mono(16)).foregroundStyle(Theme.secondaryText)
                                }
                            }
                            if let phone = recipient.phone {
                                Text(phone).font(.mono(14)).foregroundStyle(Theme.secondaryText)
                            }
                        }
                        Spacer()
                    }
                    .padding(16)
                    Divider().background(Theme.border)
                    Toggle(isOn: $mayCall) {
                        Text("Yes, the delivery partner may call Ma on this number.")
                            .font(.mono(13)).foregroundStyle(Theme.ink)
                    }
                    .toggleStyle(.checklist)
                    .padding(16)
                }
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    labeledField("Name", text: $recipientName, placeholder: "Ma")
                    labeledField("Phone", text: $recipientPhone, placeholder: "+91 98300 12345")
                }
                .padding(16)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            }
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.mono(12)).foregroundStyle(Theme.secondaryText)
            TextField(placeholder, text: text)
                .font(.mono(15))
                .foregroundStyle(Theme.ink)
        }
    }

    private func load() async {
        addresses = (try? await APIClient.shared.addresses()) ?? []
        recipients = (try? await APIClient.shared.recipients()) ?? []
        selectedAddressId = addresses.first?.id
        isLoading = false
    }

    private func save() {
        errorMessage = nil
        isSaving = true
        Task {
            do {
                var recipientId = recipients.first?.id
                if recipientId == nil {
                    let created = try await APIClient.shared.createRecipient(name: recipientName, relation: "Ma", phone: recipientPhone.isEmpty ? nil : recipientPhone)
                    recipientId = created.id
                }

                var addressId = selectedAddressId
                if isAddingAddress || addresses.isEmpty {
                    let created = try await APIClient.shared.createAddress(
                        recipientId: recipientId, label: newLabel, line1: newLine1,
                        city: newCity.isEmpty ? nil : newCity, pincode: newPincode.isEmpty ? nil : newPincode
                    )
                    addressId = created.id
                }

                guard let finalAddressId = addressId else {
                    isSaving = false
                    return
                }
                isSaving = false
                path.append(.paste(addressId: finalAddressId))
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack { AddressView(path: .constant([])) }
}
