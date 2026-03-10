//
//  OLWUISDKHelper.swift
//  SwiftSampleApp
//
//  Created by amrendra.roy on 29/09/25.
//

import UIKit
import PayUOLWUIKit
import PayUOLWParamKit
import PayUOLWCoreKit

class OLWUISDKHelper: PayUOLWDelegate {
    
    var salt: String = ""
    private var parentVC: UIViewController?
    
    func openPayUOLWSDK(parentVC: UIViewController, olwParams: PayUOLWParams) {
        self.parentVC = parentVC
        PayUOLWUISdk.openPayUOLWSDK(parentVC: parentVC, olwParams: olwParams, delegate: self)
    }
}


extension OLWUISDKHelper {
    
    func hashGeneration(
        for param: [String : String],
        completion: @escaping ([String : String]) -> Void
    ) {
        let commandName = (param[PayUOLWParamHashConstants.hashName] ?? "")
        let hashStringWithoutSalt = (param[PayUOLWParamHashConstants.hashString] ?? "")
        let postSalt = param[PayUOLWParamHashConstants.postSalt]
        // get hash for "commandName" from server
        // get hash for "hashStringWithoutSalt" from server
        
        // After fetching hash set its value in below variable "hashValue"
        var hashValue = ""
        if let postSalt = postSalt {
            let hashString = hashStringWithoutSalt + salt + postSalt
            hashValue = "assigned Your hash logic here" //Utils.sha512Hex(string: hashString)
        } else {
            hashValue = "assigned Your hash logic here + salt"  //Utils.sha512Hex(string: hashStringWithoutSalt + salt)
        }
        completion([commandName: hashValue])
    }
    
    func onError(response: PayUOLWCoreServiceResponse?) {
        debugPrint("Failure ", response ?? "")
        showAlert(title: "Failure", response: response)
    }
    
    func onSDKClosed() {
        debugPrint("Cancel ")
    }
    
    func showAlert(title: String, response: Any?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            var text = ""
            if let response = response as? PayUOLWCoreServiceResponse,
                let result = response.result as? Encodable {
                text += "Code - \(response.code)\n"
                text += "Message - \(response.message ?? "NIL")\n"
                text += "Response - "
                text += self.encodeToJSONString(result) ?? "NIL"
            } else if let response = response as? PayUOLWCoreServiceResponse {
                text += "Code - \(response.code)\n"
                text += "Message - \(response.message ?? "NIL")\n"
                text += "Response - \(response.result ?? "NIL")"
            } else {
                text += String(describing: response ?? "NIL")
            }
            let alert = UIAlertController(title: title, message: text, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.parentVC?.present(alert, animated: true)
        }
    }

    func encodeToJSONString<T: Encodable>(_ object: T) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let jsonData = try encoder.encode(object)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            return "Encoding error: \(error)"
        }
    }

}
