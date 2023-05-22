import XCTest
@testable import BraintreeCore
@testable import BraintreeSEPADirectDebit
@testable import BraintreeTestShared
import AuthenticationServices

class BTSEPADirectDebitClient_Tests: XCTestCase {
    
    var billingAddress = BTPostalAddress()
    var sepaDirectDebitRequest = BTSEPADirectDebitRequest()
    var mockAPIClient : MockAPIClient = MockAPIClient(authorization: "development_client_key")!

    override func setUp() {
        mockAPIClient = MockAPIClient(authorization: "development_tokenization_key")!

        billingAddress.streetAddress = "Kantstraße 70"
        billingAddress.extendedAddress = "#170"
        billingAddress.locality = "Freistaat Sachsen"
        billingAddress.region = "Annaberg-buchholz"
        billingAddress.postalCode = "09456"
        billingAddress.countryCodeAlpha2 = "FR"
        
        sepaDirectDebitRequest.accountHolderName = "John Doe"
        sepaDirectDebitRequest.iban = "FR891751244434203564412313"
        sepaDirectDebitRequest.customerID = "A0E243A0A200491D929D"
        sepaDirectDebitRequest.mandateType = .oneOff
        sepaDirectDebitRequest.billingAddress = billingAddress
        sepaDirectDebitRequest.merchantAccountID = "eur_pwpp_multi_account_merchant_account"
    }

    func testTokenizeWithPresentationContext_callsCreateMandateWithError_returnsError_andSendsAnalytics() {
        let sepaDirectDebitClient = BTSEPADirectDebitClient(apiClient: mockAPIClient)
        let mockSepaDirectDebitAPI = SEPADirectDebitAPI(apiClient: mockAPIClient)
        mockAPIClient.cannedResponseError = NSError(
            domain: "CannedError",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "This is a create mandate fake error"]
        )

        sepaDirectDebitClient.sepaDirectDebitAPI = mockSepaDirectDebitAPI
        
        sepaDirectDebitClient.tokenize(sepaDirectDebitRequest) { nonce, error in
            if error != nil, let error = error as NSError? {
                XCTAssertEqual(error.domain, "CannedError")
                XCTAssertEqual(error.code, 0)
                XCTAssertEqual(error.localizedDescription, "This is a create mandate fake error")
                XCTAssertTrue(self.mockAPIClient.postedAnalyticsEvents.contains(BTSEPADirectAnalytics.createMandateFailed))
            } else if nonce != nil {
                XCTFail("This request should return an error.")
            }
        }
    }
    
    func testTokenizeWithPresentationContext_handleWebAuthenticationSessionResultCalledWithCanceledSession_returnsError_andSendsAnalytics() {
        let mockWebAuthenticationSession = MockWebAuthenticationSession()
        let mockSepaDirectDebitAPI = SEPADirectDebitAPI(apiClient: mockAPIClient)
        
        mockAPIClient.cannedResponseBody = BTJSON(
            value: [
                "message": [
                    "body": [
                        "sepaDebitAccount": [
                            "approvalUrl": "https://example-success",
                            "ibanLastFour": "1234",
                            "merchantOrPartnerCustomerId": "a-customer-id",
                            "bankReferenceToken": "a-bank-reference-token",
                            "mandateType": "ONE_OFF"
                        ]
                    ]
                ]
            ]
        )

        mockWebAuthenticationSession.cannedErrorResponse = ASWebAuthenticationSessionError(
            _bridgedNSError: NSError(
                domain: ASWebAuthenticationSessionError.errorDomain,
                code: ASWebAuthenticationSessionError.canceledLogin.rawValue,
                userInfo: ["Description": "Mock cancellation error description."]
            )
        )

        let sepaDirectDebitClient = BTSEPADirectDebitClient(
            apiClient: mockAPIClient,
            webAuthenticationSession: mockWebAuthenticationSession,
            sepaDirectDebitAPI: mockSepaDirectDebitAPI
        )

        sepaDirectDebitClient.tokenize(sepaDirectDebitRequest) { nonce, error in
            if error != nil, let error = error as NSError? {
                XCTAssertEqual(error.domain, SEPADirectDebitError.errorDomain)
                XCTAssertEqual(error.code, SEPADirectDebitError.webFlowCanceled.errorCode)
                XCTAssertEqual(error.localizedDescription, SEPADirectDebitError.webFlowCanceled.localizedDescription)
                XCTAssertTrue(self.mockAPIClient.postedAnalyticsEvents.contains(BTSEPADirectAnalytics.challengeCanceled))
            } else if nonce != nil {
                XCTFail("This request should return an error.")
            }
        }
    }
    
    func testTokenizeWithPresentationContext_handleWebAuthenticationSessionResultCalledWithInvalidContext_returnsError_andSendsAnalytics() {
        let mockWebAuthenticationSession = MockWebAuthenticationSession()
        let mockSepaDirectDebitAPI = SEPADirectDebitAPI(apiClient: mockAPIClient)

        mockAPIClient.cannedResponseBody = BTJSON(
            value: [
                "message": [
                    "body": [
                        "sepaDebitAccount": [
                            "approvalUrl": "https://example-success",
                            "ibanLastFour": "1234",
                            "merchantOrPartnerCustomerId": "a-customer-id",
                            "bankReferenceToken": "a-bank-reference-token",
                            "mandateType": "ONE_OFF"
                        ]
                    ]
                ]
            ]
        )

        mockWebAuthenticationSession.cannedErrorResponse = ASWebAuthenticationSessionError(
            _bridgedNSError: NSError(
                domain: ASWebAuthenticationSessionError.errorDomain,
                code: ASWebAuthenticationSessionError.presentationContextInvalid.rawValue,
                userInfo: ["Description": "Mock cancellation error description."]
            )
        )

        let sepaDirectDebitClient = BTSEPADirectDebitClient(
            apiClient: mockAPIClient,
            webAuthenticationSession: mockWebAuthenticationSession,
            sepaDirectDebitAPI: mockSepaDirectDebitAPI
        )

        sepaDirectDebitClient.tokenize(sepaDirectDebitRequest) { nonce, error in
            if error != nil, let error = error as NSError? {
                XCTAssertEqual(error.domain, SEPADirectDebitError.errorDomain)
                XCTAssertEqual(error.code, SEPADirectDebitError.presentationContextInvalid.errorCode)
                XCTAssertEqual(error.localizedDescription, SEPADirectDebitError.presentationContextInvalid.localizedDescription)
            } else if nonce != nil {
                XCTFail("This request should return an error.")
            }
        }
    }
    
    func testTokenizeWithPresentationContext_handleWebAuthenticationSessionResultCalledWithInvalidResponseURL_returnsError_andSendsAnalytics() {
        let mockWebAuthenticationSession = MockWebAuthenticationSession()
        let mockSepaDirectDebitAPI = SEPADirectDebitAPI(apiClient: mockAPIClient)

        mockAPIClient.cannedResponseBody = BTJSON(
            value: [
                "message": [
                    "body": [
                        "sepaDebitAccount": [
                            "approvalUrl": "https://example-success",
                            "last4": "1234",
                            "merchantOrPartnerCustomerId": "a-customer-id",
                            "bankReferenceToken": "a-bank-reference-token",
                            "mandateType": "ONE_OFF"
                        ]
                    ]
                ]
            ]
        )

        mockWebAuthenticationSession.cannedResponseURL = URL(string: "invalid-url")

        let sepaDirectDebitClient = BTSEPADirectDebitClient(
            apiClient: mockAPIClient,
            webAuthenticationSession: mockWebAuthenticationSession,
            sepaDirectDebitAPI: mockSepaDirectDebitAPI
        )

        sepaDirectDebitClient.tokenize(sepaDirectDebitRequest) { nonce, error in
            if error != nil, let error = error as NSError? {
                XCTAssertEqual(error.domain, SEPADirectDebitError.errorDomain)
                XCTAssertEqual(error.code, SEPADirectDebitError.resultURLInvalid.errorCode)
                XCTAssertEqual(error.localizedDescription, SEPADirectDebitError.resultURLInvalid.localizedDescription)
                XCTAssertTrue(self.mockAPIClient.postedAnalyticsEvents.contains(BTSEPADirectAnalytics.challengeFailed))
            } else if nonce != nil {
                XCTFail("This request should return an error.")
            }
        }
    }
    
    func testTokenizeWithPresentationContext_handleCreateMandateReturnsNoErrorOrResult_returnsError_andSendsAnalytics() {
        let mockWebAuthenticationSession = MockWebAuthenticationSession()
        let mockSepaDirectDebitAPI = SEPADirectDebitAPI(apiClient: mockAPIClient)

        mockWebAuthenticationSession.cannedErrorResponse = NSError(
            domain: SEPADirectDebitError.errorDomain,
            code: SEPADirectDebitError.noBodyReturned.errorCode,
            userInfo: ["Description": "Mock noBodyReturned error description."]
        )

        let sepaDirectDebitClient = BTSEPADirectDebitClient(
            apiClient: mockAPIClient,
            webAuthenticationSession: mockWebAuthenticationSession,
            sepaDirectDebitAPI: mockSepaDirectDebitAPI
        )
        
        mockAPIClient.cannedResponseBody = nil

        sepaDirectDebitClient.tokenize(sepaDirectDebitRequest) { nonce, error in
            if error != nil, let error = error as NSError? {
                XCTAssertEqual(error.domain, SEPADirectDebitError.errorDomain)
                XCTAssertEqual(error.code, SEPADirectDebitError.noBodyReturned.errorCode)
                XCTAssertEqual(error.localizedDescription, SEPADirectDebitError.noBodyReturned.localizedDescription)
                XCTAssertTrue(self.mockAPIClient.postedAnalyticsEvents.contains(BTSEPADirectAnalytics.createMandateFailed))
            } else if nonce != nil {
                XCTFail("This request should return an error.")
            }
        }
    }

    func testTokenizeWithPresentationContext_handleCreateMandateReturnsInvalidURL_returnsError_andSendsAnalytics() {
        let mockWebAuthenticationSession = MockWebAuthenticationSession()
        let mockSepaDirectDebitAPI = SEPADirectDebitAPI(apiClient: mockAPIClient)

        mockAPIClient.cannedResponseBody = BTJSON(
            value: [
                "message": [
                    "body": [
                        "sepaDebitAccount": [
                            "approvalUrl": "   ",
                            "last4": "1234",
                            "merchantOrPartnerCustomerId": "a-customer-id",
                            "bankReferenceToken": "a-bank-reference-token",
                            "mandateType": "ONE_OFF"
                        ]
                    ]
                ]
            ]
        )

        mockWebAuthenticationSession.cannedErrorResponse = NSError(
            domain: SEPADirectDebitError.errorDomain,
            code: SEPADirectDebitError.approvalURLInvalid.errorCode,
            userInfo: ["Description": "Mock approvalURLInvalid error description."]
        )

        let sepaDirectDebitClient = BTSEPADirectDebitClient(
            apiClient: mockAPIClient,
            webAuthenticationSession: mockWebAuthenticationSession,
            sepaDirectDebitAPI: mockSepaDirectDebitAPI
        )

        sepaDirectDebitClient.tokenize(sepaDirectDebitRequest) { nonce, error in
            if error != nil, let error = error as NSError? {
                XCTAssertEqual(error.domain, SEPADirectDebitError.errorDomain)
                XCTAssertEqual(error.code, SEPADirectDebitError.approvalURLInvalid.errorCode)
                XCTAssertEqual(error.localizedDescription, SEPADirectDebitError.approvalURLInvalid.localizedDescription)
                XCTAssertTrue(self.mockAPIClient.postedAnalyticsEvents.contains(BTSEPADirectAnalytics.createMandateFailed))
            } else if nonce != nil {
                XCTFail("This request should return an error.")
            }
        }
    }

    func testTokenizeWithPresentationContext_handleWebAuthenticationSessionSuccessURLInvalid_returnsError_andSendsAnalytics() {
        let mockWebAuthenticationSession = MockWebAuthenticationSession()
        let mockSepaDirectDebitAPI = SEPADirectDebitAPI(apiClient: mockAPIClient)

        mockAPIClient.cannedResponseBody = BTJSON(
            value: [
                "message": [
                    "body": [
                        "sepaDebitAccount": [
                            "approvalUrl": "https://example-success",
                            "last4": "1234",
                            "merchantOrPartnerCustomerId": "a-customer-id",
                            "bankReferenceToken": "a-bank-reference-token",
                            "mandateType": "ONE_OFF"
                        ]
                    ]
                ]
            ]
        )

        mockWebAuthenticationSession.cannedResponseURL = nil

        let sepaDirectDebitClient = BTSEPADirectDebitClient(
            apiClient: mockAPIClient,
            webAuthenticationSession: mockWebAuthenticationSession,
            sepaDirectDebitAPI: mockSepaDirectDebitAPI
        )

        sepaDirectDebitClient.tokenize(sepaDirectDebitRequest) { nonce, error in
            if error != nil, let error = error as NSError? {
                XCTAssertEqual(error.domain, SEPADirectDebitError.errorDomain)
                XCTAssertEqual(error.code, SEPADirectDebitError.authenticationResultNil.errorCode)
                XCTAssertEqual(error.localizedDescription, SEPADirectDebitError.authenticationResultNil.localizedDescription)
                XCTAssertTrue(self.mockAPIClient.postedAnalyticsEvents.contains(BTSEPADirectAnalytics.challengeFailed))
            } else if nonce != nil {
                XCTFail("This request should return an error.")
            }
        }
    }
    
    func testTokenizeWithPresentationContext_callsTokenizeWithAlreadyApprovedMandate_returnsSuccess_andSendsAnalytics() {
        let mockWebAuthenticationSession = MockWebAuthenticationSession()
        let mockSepaDirectDebitAPI = SEPADirectDebitAPI(apiClient: mockAPIClient)

        mockAPIClient.cannedResponseBody = BTJSON(
            value: [
                "message": [
                    "body": [
                        "sepaDebitAccount": [
                            "approvalUrl": "null",
                            "last4": "1234",
                            "merchantOrPartnerCustomerId": "a-customer-id",
                            "bankReferenceToken": "a-bank-reference-token",
                            "mandateType": "ONE_OFF"
                        ]
                    ]
                ]
            ]
        )
        
        let mockTokenizeResponse = BTJSON(
            value: [
                "nonce": "a-fake-payment-method-nonce",
                "details": [
                    "ibanLastChars": "1234",
                    "merchantOrPartnerCustomerId": "a-customer-id",
                    "mandateType": "RECURRENT"
                ]
            ] as [String: Any]
        )
        
        mockWebAuthenticationSession.cannedResponseURL = URL(string: "https://example/sepa/success?success=true")
        mockAPIClient.cannedResponseBody = BTJSON(value: mockTokenizeResponse)
        
        let sepaDirectDebitClient = BTSEPADirectDebitClient(
            apiClient: mockAPIClient,
            webAuthenticationSession: mockWebAuthenticationSession,
            sepaDirectDebitAPI: mockSepaDirectDebitAPI
        )
        
        sepaDirectDebitClient.tokenize(sepaDirectDebitRequest) { nonce, error in
            if error != nil {
                XCTFail("This request should be successful.")
            } else if nonce != nil {
                XCTAssertEqual(nonce?.nonce, "a-fake-payment-method-nonce")
                XCTAssertEqual(nonce?.ibanLastFour, "1234")
                XCTAssertEqual(nonce?.customerID, "a-customer-id")
                XCTAssertEqual(nonce?.mandateType?.description, "RECURRENT")
                XCTAssertTrue(self.mockAPIClient.postedAnalyticsEvents.contains(BTSEPADirectAnalytics.tokenizeSucceeded))
            }
        }
    }

    func testTokenizeWithPresentationContext_callsTokenize_returnsSuccess_andSendsAnalytics() {
        let mockWebAuthenticationSession = MockWebAuthenticationSession()
        let mockSepaDirectDebitAPI = SEPADirectDebitAPI(apiClient: mockAPIClient)

        mockAPIClient.cannedResponseBody = BTJSON(
            value: [
                "message": [
                    "body": [
                        "sepaDebitAccount": [
                            "approvalUrl": "https://example-success",
                            "last4": "1234",
                            "merchantOrPartnerCustomerId": "a-customer-id",
                            "bankReferenceToken": "a-bank-reference-token",
                            "mandateType": "ONE_OFF"
                        ]
                    ]
                ]
            ]
        )
        
        let mockTokenizeResponse = BTJSON(
            value: [
                "nonce": "a-fake-payment-method-nonce",
                "details": [
                    "ibanLastChars": "1234",
                    "merchantOrPartnerCustomerId": "a-customer-id",
                    "mandateType": "RECURRENT"
                ]
            ] as [String: Any]
        )
        
        mockWebAuthenticationSession.cannedResponseURL = URL(string: "https://example/sepa/success?success=true")
        mockAPIClient.cannedResponseBody = BTJSON(value: mockTokenizeResponse)

        let sepaDirectDebitClient = BTSEPADirectDebitClient(
            apiClient: mockAPIClient,
            webAuthenticationSession: mockWebAuthenticationSession,
            sepaDirectDebitAPI: mockSepaDirectDebitAPI
        )
        
        sepaDirectDebitClient.tokenize(sepaDirectDebitRequest) { nonce, error in
            if error != nil {
                XCTFail("This request should be successful.")
            } else if nonce != nil {
                XCTAssertEqual(nonce?.nonce, "a-fake-payment-method-nonce")
                XCTAssertEqual(nonce?.ibanLastFour, "1234")
                XCTAssertEqual(nonce?.customerID, "a-customer-id")
                XCTAssertEqual(nonce?.mandateType?.description, "RECURRENT")
                XCTAssertTrue(self.mockAPIClient.postedAnalyticsEvents.contains(BTSEPADirectAnalytics.tokenizeSucceeded))
            }
        }
    }
    
    func testTokenizeWithPresentationContext_callsTokenizeWithAlreadyApprovedMandate_returnsError_andSendsAnalytics() {
        let mockWebAuthenticationSession = MockWebAuthenticationSession()
        let mockSepaDirectDebitAPI = SEPADirectDebitAPI(apiClient: mockAPIClient)

        mockAPIClient.cannedResponseBody = BTJSON(
            value: [
                "message": [
                    "body": [
                        "sepaDebitAccount": [
                            "approvalUrl": "null",
                            "last4": "1234",
                            "merchantOrPartnerCustomerId": "a-customer-id",
                            "bankReferenceToken": "a-bank-reference-token",
                            "mandateType": "ONE_OFF"
                        ]
                    ]
                ]
            ]
        )

        mockWebAuthenticationSession.cannedResponseURL = URL(string: "https://example/sepa/success?success=true")
        mockAPIClient.cannedResponseError = NSError(
            domain: "CannedError",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "This is a fake tokenize request error"]
        )

        let sepaDirectDebitClient = BTSEPADirectDebitClient(
            apiClient: mockAPIClient,
            webAuthenticationSession: mockWebAuthenticationSession,
            sepaDirectDebitAPI: mockSepaDirectDebitAPI
        )

        sepaDirectDebitClient.tokenize(sepaDirectDebitRequest) { nonce, error in
            if error != nil, let error = error as NSError? {
                XCTAssertEqual(error.domain, "CannedError")
                XCTAssertEqual(error.code, 0)
                XCTAssertEqual(error.localizedDescription, "This is a fake tokenize request error")
                XCTAssertTrue(self.mockAPIClient.postedAnalyticsEvents.contains(BTSEPADirectAnalytics.createMandateFailed))
            } else if nonce != nil {
                XCTFail("This request should be return an error.")
            }
        }
    }
    
    func testTokenizeWithPresentationContext_callsTokenize_returnsError_andSendsAnalytics() {
        let mockWebAuthenticationSession = MockWebAuthenticationSession()
        let mockSepaDirectDebitAPI = SEPADirectDebitAPI(apiClient: mockAPIClient)

        mockAPIClient.cannedResponseBody = BTJSON(
            value: [
                "message": [
                    "body": [
                        "sepaDebitAccount": [
                            "approvalUrl": "https://example-success",
                            "last4": "1234",
                            "merchantOrPartnerCustomerId": "a-customer-id",
                            "bankReferenceToken": "a-bank-reference-token",
                            "mandateType": "ONE_OFF"
                        ]
                    ]
                ]
            ]
        )

        mockWebAuthenticationSession.cannedResponseURL = URL(string: "https://example/sepa/success?success=true")
        mockAPIClient.cannedResponseError = NSError(
            domain: "CannedError",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "This is a fake tokenize request error"]
        )

        let sepaDirectDebitClient = BTSEPADirectDebitClient(
            apiClient: mockAPIClient,
            webAuthenticationSession: mockWebAuthenticationSession,
            sepaDirectDebitAPI: mockSepaDirectDebitAPI
        )

        sepaDirectDebitClient.tokenize(sepaDirectDebitRequest) { nonce, error in
            if error != nil, let error = error as NSError? {
                XCTAssertEqual(error.domain, "CannedError")
                XCTAssertEqual(error.code, 0)
                XCTAssertEqual(error.localizedDescription, "This is a fake tokenize request error")
                XCTAssertTrue(self.mockAPIClient.postedAnalyticsEvents.contains(BTSEPADirectAnalytics.createMandateFailed))
            } else if nonce != nil {
                XCTFail("This request should be return an error.")
            }
        }
    }
}
