//
//  BTPayPalClientAppLaunchConfig.swift
//  Braintree
//
//  Created by Abhinay Balusu on 2/3/25.
//

import Foundation

/// Used for switching to either PayPal app or open fallback url in a browser authentication session
struct BTPayPalClientAppLaunchConfig {

    // The universal link URL used to launch the PayPal client app.
    let appSwitchUrl: URL

    // The BA (Billing Agreement) token
    let baToken: String

    // An optional fallback URL to be used if the universal link fails.
    let fallbackUrl: URL?

    init(appSwitchUrl: URL, baToken: String, fallbackUrl: URL? = nil) {
        self.appSwitchUrl = appSwitchUrl
        self.baToken = baToken
        self.fallbackUrl = fallbackUrl
    }
}
