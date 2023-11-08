import Foundation
import CallKit
import linphonesw
import AVFoundation


@objc
class SipPhoneCallKitProviderDelegate : NSObject
{
    private let provider: CXProvider
    let mCallController = CXCallController()
    var sipPhoneCtx : SipPhoneControl!

    var activeCallUUID : UUID!

    var callHandledInApp : Bool = false

    init(context: SipPhoneControl)
    {
        sipPhoneCtx = context
        // let providerConfiguration = CXProviderConfiguration(localizedName: Bundle.main.infoDictionary!["CFBundleName"] as! String)
        let providerConfiguration = CXProviderConfiguration(localizedName: Bundle.main.infoDictionary!["CFBundleDisplayName"] as! String)
        providerConfiguration.supportsVideo = true
        providerConfiguration.supportedHandleTypes = [.generic]
        // providerConfiguration.includesCallsInRecents =

        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.maximumCallGroups = 1

        provider = CXProvider(configuration: providerConfiguration)
        super.init()
        provider.setDelegate(self, queue: nil) // The CXProvider delegate will trigger CallKit related callbacks

    }

    func incomingCall()
    {
        NSLog("[SipPhoneCallKitProviderDelegate]: incomingCall")

        activeCallUUID = UUID()
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type:.generic, value: sipPhoneCtx.incomingCallName)

        provider.reportNewIncomingCall(with: activeCallUUID, update: update, completion: { error in }) // Report to CallKit a call is incoming

        callHandledInApp = false;
    }


    func outgoingCallStarted()
    {
        activeCallUUID = UUID()

        NSLog("[SipPhoneCallKitProviderDelegate]: generate new UUID")

        let handle = CXHandle(type: .phoneNumber, value: "XXXXXXXXXX")

        let startCallAction = CXStartCallAction(call: activeCallUUID, handle: handle)

        let transaction = CXTransaction(action: startCallAction)

        mCallController.request(transaction) { error in
            if let error = error {
                print("[SipPhoneCallKitProviderDelegate]: Error requesting transaction: \(error)")
            } else {
                print("[SipPhoneCallKitProviderDelegate]: Requested transaction successfully")
            }
        }


    //    NSLog("[SipPhoneCallKitProviderDelegate]: outgoingCallStarted \(activeCallUUID ?? "activeCallUUID")")

        provider.reportOutgoingCall(with: activeCallUUID, startedConnectingAt: nil) // Report to CallKit
    }

    func outgoingCallConnected()
    {

   //     NSLog("[SipPhoneCallKitProviderDelegate]: outgoingCallConnected with ID \(activeCallUUID ?? "activeCallUUID")

        provider.reportOutgoingCall(with: activeCallUUID, connectedAt: nil) // Report to CallKit
    }

    func stopCall(_callHandledInApp: Bool)
    {
    //    NSLog("[SipPhoneCallKitProviderDelegate]: [stopCall] activeCallUUID: \(activeCallUUID ?? "activeCallUUID")

        callHandledInApp = _callHandledInApp

        let transaction = CXTransaction(action: CXEndCallAction(call: activeCallUUID!))

        mCallController.request(transaction, completion: { error in
            NSLog("[SipPhoneCallKitProviderDelegate]: stoCall error \(error)")
        }) // Report to CallKit a call must end
    }

}


// In this extension, we implement the action we want to be done when CallKit is notified of something.
// This can happen through the CallKit GUI in the app, or directly in the code (see, incomingCall(), stopCall() functions above)
extension SipPhoneCallKitProviderDelegate: CXProviderDelegate {

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        NSLog("[sip]: CXProviderDelegate CXEndCallAction")

        if(callHandledInApp) {
            NSLog("[sip]: CXProviderDelegate callHandledInApp")
        } else {

            do {
                if (sipPhoneCtx.mCall?.state != .End && sipPhoneCtx.mCall?.state != .Released)  {
                    try sipPhoneCtx.mCall?.terminate()
                }
            } catch {
                NSLog(error.localizedDescription)

                NSLog("[sip]: CXEndCallAction")
            }

            sipPhoneCtx.isCallRunning = false
            sipPhoneCtx.isCallIncoming = false
            sipPhoneCtx.isCallOutgoing = false
        }

        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        NSLog("[sip]: CXProviderDelegate CXAnswerCallAction")
        do {
            sipPhoneCtx.mCore.configureAudioSession()

            try sipPhoneCtx.mCall?.accept()
            sipPhoneCtx.isCallRunning = true
        } catch {
            NSLog("[sip]: CXAnswerCallAction error")
            NSLog(error.localizedDescription)
            print(error)
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        NSLog("[CXProviderDelegate]: CXSetHeldCallAction")
        action.fulfill()
    }
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        sipPhoneCtx.mCore.configureAudioSession()
        sipPhoneCtx.isCallRunning = true


        action.fulfill()
    }
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        action.fulfill()
    }
    func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        action.fulfill()
    }
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        action.fulfill()
    }
    func providerDidReset(_ provider: CXProvider) {
        NSLog("[CXProviderDelegate]: providerDidReset")
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        NSLog("[CXProviderDelegate]: didActivate")
        sipPhoneCtx.mCore.activateAudioSession(actived: true)
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        NSLog("[CXProviderDelegate]: didDeactivate")
        sipPhoneCtx.mCore.activateAudioSession(actived: false)
    }
}
