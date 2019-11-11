import UIKit
import Flutter
import FBSDKCoreKit
import FBSDKShareKit

let CHANNEL = "my_flutter_wallpaper"
let SET_WALLPAPER = "setWallpaper"
let SCAN_FILE = "scanFile"
let SHARE_IMAGE_TO_FACEBOOK = "shareImageToFacebook"
let RESIZE_IMAGE = "resizeImage"

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {


    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)

        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel.init(name: CHANNEL, binaryMessenger: controller.binaryMessenger)

        channel.setMethodCallHandler { [weak self] (methodCall, result) in

            switch methodCall.method {
            case SET_WALLPAPER:
                let controller = UIAlertController.init(title: "Set wallpaper", message: "Go to Photos, select image and set it as wallpaper", preferredStyle: .alert)
                controller.addAction(.init(title: "OK", style: .default, handler: nil))
                self?.window?.rootViewController?.present(controller, animated: true, completion: nil)
                result(nil)
            case SCAN_FILE:
                guard let arguments = methodCall.arguments as? [String] else {
                    return result(FlutterError.init(code: "error", message: "Arguments error", details: nil))
                }
                scanFile(result: result, path: arguments)
            case SHARE_IMAGE_TO_FACEBOOK:
                self?.shareImageToFacebook(
                    result: result,
                    imageUrl: methodCall.arguments as? String
                )
            case RESIZE_IMAGE:
                guard let arguments = methodCall.arguments as? [String: Any] else {
                    return result(FlutterError.init(code: "error", message: "Arguments error", details: nil))
                }

                let bytes = arguments["bytes"] as? FlutterStandardTypedData
                let width = arguments["width"] as? Int
                let height = arguments["height"] as? Int
                resizeImage(
                    result: result,
                    bytes: bytes,
                    width: width,
                    height: height
                )
            default:
                result(FlutterMethodNotImplemented)
            }
        }


        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        return ApplicationDelegate.shared.application(application, open: url, sourceApplication: sourceApplication, annotation: annotation)
    }



    func shareImageToFacebook(result: FlutterResult, imageUrl: String?) {
        guard let imageUrl = imageUrl, let url = URL.init(string: imageUrl) else {
            return result(FlutterError(code: "error", message: "imageUrl cannot be null", details: nil))
        }

        let photo = SharePhoto.init(imageURL: url, userGenerated: true)
        let shareContent = SharePhotoContent.init()
        shareContent.photos = [photo]

        guard let vc = self.window.rootViewController else {
            return result(FlutterError(code: "error", message: "An error occurred", details: nil))
        }
        let shareDialog = ShareDialog.init(fromViewController: vc, content: shareContent, delegate: self)
        if shareDialog.canShow {
            shareDialog.show()
            result("Show share dialog")
        } else {
            let alertVC = UIAlertController.init(title: "Error", message: "It looks like you don't have the Facebook mobile app on your phone", preferredStyle: .alert)
            alertVC.addAction(.init(title: "OK", style: .default, handler: nil))
            vc.present(alertVC, animated: true, completion: nil)
            result(FlutterError(code: "error", message: "Cannot show share dialog", details: nil))
        }
    }

}

extension AppDelegate: SharingDelegate {
    func sharer(_ sharer: Sharing, didCompleteWithResults results: [String : Any]) {
        print("Fb share completed")
    }
    
    func sharer(_ sharer: Sharing, didFailWithError error: Error) {
        print("Fb share error: \(error)")
    }
    
    func sharerDidCancel(_ sharer: Sharing) {
        print("Fb share cancel")
    }
}

func resizeImage(
    result: (Any?) -> (),
    bytes: FlutterStandardTypedData?,
    width: Int?,
    height: Int?
) {
    guard let data = bytes?.data, let image = UIImage.init(data: data) else {
        return result(FlutterError.init(code: "error", message: "bytes cannot be null", details: nil))
    }
    guard let width = width else {
        return result(FlutterError.init(code: "error", message: "width cannot be null", details: nil))
    }
    guard let height = height else {
        return result(FlutterError.init(code: "error", message: "height cannot be null", details: nil))
    }

    let resizedImage = resizeImage(image: image, targetSize: .init(width: width, height: height))
    if let data = UIImagePNGRepresentation(resizedImage) {
        result(FlutterStandardTypedData.init(bytes: data))
    } else {
        result(FlutterError.init(code: "error", message: "Resize image error", details: nil))
    }
}

func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
    let size = image.size

    let widthRatio = targetSize.width / image.size.width
    let heightRatio = targetSize.height / image.size.height

    // Figure out what our orientation is, and use that to form the rectangle
    let newSize: CGSize
    if(widthRatio > heightRatio) {
        newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
    } else {
        newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
    }

    // This is the rect that we've calculated out and this is what is actually used below
    let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

    // Actually do the resizing to the rect using the ImageContext stuff
    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
    image.draw(in: rect)
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return newImage!
}


func scanFile(result: (Any?) -> Void, path: [String]?) {
    guard let path = path else {
        return result(FlutterError.init(
            code: "error",
            message: "Path cannot be null",
            details: nil))
    }
    guard let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else {
            return result(FlutterError.init(
                code: "error",
                message: "Document directory is not exist",
                details: nil))
    }

    let imageUrl = documentDir.appendingPathComponent(path.joined(separator: "/"))

    if let data = try? Data(contentsOf: imageUrl), let image = UIImage(data: data) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    result("Scan file done")
}
