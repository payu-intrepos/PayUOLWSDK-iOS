//
//  ContentView.swift
//  OLWSwiftSampleApp
//
//  Created by amrendra.roy on 10/03/26.
//

import SwiftUI
import PayUOLWParamKit
import PayUOLWUIKit

struct SampleRowSegment: View {
    var title: String
    @Binding var value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
                .frame(maxWidth: 140, alignment: .leading)
            
            TextField(value, text: $value)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .frame(maxWidth: .infinity)
        }
    }
}

struct SampleBoolRowSegment: View {
    var title: String
    @Binding var value: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
            
            Spacer()
            
            Toggle("", isOn: $value)
                .toggleStyle(SwitchToggleStyle())
        }
        .padding(.horizontal, 4)
    }
}

struct ContentView: View {
    
    private var helper: OLWUISDKHelper? = OLWUISDKHelper()
    @State private var merchantName: String = "merchantLogo" // <#YourAppLogoIconname#>
    
    // UAT
    @State private var merchantKey: String = "key" // <#Your Key#>
    @State private var salt = "salt" // <#Yoursalt#>
    
    @State private var primaryColor: String = "#FFAC1C" // <#Primary Color#>
    @State private var isProduction: Bool = false // Change this as true for production
    @State private var merchantSupportEmail = "merchantsupport@gmail.com" // <#Support Contact#>
    
    @State private var phone: String = "8237111111" // "<#Your Phone Number#>"
    
    @State private var termsAndConditionsURL: String = "https://payu.in"
    @State private var redirectionURL: String = "https://myaccount.payu.in/wallet/processing"
    @State private var payUReferenceId: String = Utils.referenceId()
    
    private func getPaymentParams() -> PayUOLWParams {
        return PayUOLWParams(
            merchantKey: merchantKey,
            merchantLogo: merchantName,
            primaryColor: primaryColor,
            customerMobile: phone,
            termsAndConditionsURL: termsAndConditionsURL,
            merchantSupportEmail: merchantSupportEmail,
            isProd: isProduction,
            kycRedirectionUrl: redirectionURL,
            payUReferenceId: payUReferenceId
        )
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                    SampleRowSegment(title: "Merchant Key", value: $merchantKey)
                    SampleRowSegment(title: "Merchant Salt", value: $salt)
                    SampleRowSegment(title: "Merchant Email", value: $merchantSupportEmail)
                    SampleRowSegment(title: "Merchant Logo/Name", value: $merchantName)
                    
                    SampleRowSegment(title: "Customer Mobile", value: $phone)
                    SampleRowSegment(title: "Primary Color", value: $primaryColor)
                    
                    SampleRowSegment(title: "Terms & Conditions URL", value: $termsAndConditionsURL)
                    SampleBoolRowSegment(title: "isProduction", value: $isProduction)
                    SampleRowSegment(title: "Redirection URL", value: $redirectionURL)
                    
                        Button {
                            launchOLWAndPay()
                        } label: {
                            Text("Open OLW Wallet SDK")
                                .padding(.all, 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.green.opacity(0.7), lineWidth: 1)
                                )
                        }

                    
                    }
                    .padding(.vertical, 12)
                }
                .navigationTitle("Sample App")
            }
            .padding(.horizontal, 8)
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Dismiss keyboard when tapping anywhere in the view
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            )
        }
    }
    
    private func launchOLWAndPay() {
        // Get the root view controller from the current window
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            debugPrint("Error: Could not find root view controller")
            return
        }
        helper?.salt = salt
        helper?.openPayUOLWSDK(parentVC: rootViewController, olwParams: getPaymentParams())
    }
}

#Preview {
    ContentView()
}
