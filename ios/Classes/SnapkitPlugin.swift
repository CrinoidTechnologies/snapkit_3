import Flutter
import UIKit

	// Snapkit Imports
import SCSDKCoreKit
import SCSDKLoginKit
import SCSDKCreativeKit

extension String: Error {}

public class SnapkitPlugin: NSObject, FlutterPlugin {
	public static func register(with registrar: FlutterPluginRegistrar) {
		let channel = FlutterMethodChannel(name: "snapkit", binaryMessenger: registrar.messenger())
		let instance = SnapkitPlugin()
		registrar.addMethodCallDelegate(instance, channel: channel)
	}
	
	var _snapApi: SCSDKSnapAPI?
	
	public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
		switch call.method {
			case "isSnapchatInstalled":
				let appScheme = "snapchat://app"
				let appUrl = URL(string: appScheme)
				result(UIApplication.shared.canOpenURL(appUrl! as URL))
			case "isLoggedIn":
				result(SCSDKLoginClient.isUserLoggedIn)
				break
			case "login":
				let uiViewController = UIApplication.shared.delegate?.window??.rootViewController
				
				if (uiViewController == nil) {
					result(FlutterError(code: "LoginError", message: "Could not get UI View Controller from iOS", details: nil))
				}
				
				SCSDKLoginClient.login(from: uiViewController, completion: { (success: Bool, error: Error?) in
					if (success) {
						result("Login Success")
					} else if (!success && error != nil) {
						result(FlutterError(code: "LoginError", message: error.debugDescription, details: nil))
					} else {
						result(FlutterError(code: "LoginError", message: "An unknown error occurred while trying to login", details: nil))
					}
				})
				break
			case "getCurrentUser":
				let queryBuilder = SCSDKUserDataQueryBuilder().withExternalId().withDisplayName().withBitmojiAvatarID().withBitmojiTwoDAvatarUrl()
				let query = queryBuilder.build()
				SCSDKLoginClient.fetchUserData(with: query,
											   success: {(userdata: SCSDKUserData?, partialError: Error?) in
					guard let data = userdata else { return }
					
					let map: [String: String?] = [
						"externalId": data.externalID,
						"displayName": data.displayName,
						"bitmoji2DAvatarUrl": data.bitmojiTwoDAvatarUrl,
						"bitmojiAvatarId": data.bitmojiAvatarID,
						"errors": partialError != nil ? partialError.debugDescription : nil
					]
					
					result(map)
				},
											   failure: {(error: Error?, isUserLoggedOut: Bool) in
					if (isUserLoggedOut) {
						result(FlutterError(code: "GetUserError", message: "User Not Logged In", details: error))
					} else if (error != nil) {
						result(FlutterError(code: "GetUserError", message: error.debugDescription, details: error))
					} else {
						result(FlutterError(code: "GetUserError", message: "An unknown error ocurred while trying to retrieve user data", details: error))
					}
				})
				break
			case "logout":
				SCSDKLoginClient.clearToken()
				result("Logout Success")
				break
			case "shareToCamera":
				guard let arguments = call.arguments,
					  let args = arguments as? [String: Any] else { return }
				
				do {
					var content = try self.handleCommonShare(args: args, content: SCSDKNoSnapContent())
					
					if (_snapApi == nil) {
						_snapApi = SCSDKSnapAPI()
					}
					
					_snapApi?.startSending(content, completionHandler: { (error: Error?) in
						if (error != nil) {
							result(FlutterError(code: "ShareToCameraError", message: error?.localizedDescription, details: nil))
						} else {
							result("ShareToCamera Success")
						}
					})
				} catch (let e) {
					result(FlutterError(code: "ShareToCameraError", message: e.localizedDescription, details: nil))
				}
				
				break
			default:
				result(FlutterMethodNotImplemented)
		}
	}
	
	public func handleCommonShare(args: [String: Any], content: SCSDKSnapContent) throws -> SCSDKSnapContent {
		content.caption = args["caption"] as? String
		content.attachmentUrl = args["link"] as? String
		
		if let sticker = args["sticker"] as? [String: Any] {
			let imagePath = sticker["imagePath"] as? String
			
			if (!FileManager.default.fileExists(atPath: imagePath!)) {
				throw "Image could not be found in filesystem"
			}
			
			guard let uiImage = UIImage(contentsOfFile: imagePath!) else {
				throw "Image could not be loaded into UIImage"
			}
			
			let size = sticker["size"] as? [String: Any]
			let offset = sticker["offset"] as? [String: Any]
			let rotation = sticker["rotation"] as? [String: Any]
			
			let snapSticker = SCSDKSnapSticker(stickerImage: uiImage)
			snapSticker.width = size?["width"] as! CGFloat
			snapSticker.height = size?["height"] as! CGFloat
			snapSticker.posX = offset?["x"] as! CGFloat
			snapSticker.posY = offset?["y"] as! CGFloat
			snapSticker.rotation = rotation?["angle"] as! CGFloat
			
			content.sticker = snapSticker
		}
		
		return content
	}
}
