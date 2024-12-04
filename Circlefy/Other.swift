//
//  Other.swift
//  Circlefy
//
//  Created by Benjamin on 12/3/24.
//

import SwiftUI
import UniformTypeIdentifiers

let RootVC = UIApplication.shared.keyWindow?.rootViewController

class IPAPickerViewControllerDelegate: NSObject, UIDocumentPickerDelegate {
    let IPAPath: Binding<String>
    init(_ IPAPath: Binding<String>) {
        self.IPAPath = IPAPath
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let FileURL = urls[0]
        IPAPath.wrappedValue = "\(NSHomeDirectory())/Documents/\(FileURL.lastPathComponent)"
        try? FileManager.default.removeItem(atPath: IPAPath.wrappedValue)
        try? FileManager.default.copyItem(atPath: FileURL.path, toPath: IPAPath.wrappedValue)
    }
}

struct IPAPicker: UIViewControllerRepresentable {
    let controllerDelegate: IPAPickerViewControllerDelegate
    init(_ IPAPath: Binding<String>) {
        controllerDelegate = IPAPickerViewControllerDelegate(IPAPath)
    }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let pickerViewController = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType(filenameExtension: "ipa")!], asCopy: true)
        pickerViewController.delegate = self.controllerDelegate
        return pickerViewController
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        
    }
}

func ProgressAlert(_ Title: String, _ Message: String) -> (UIAlertController, UIProgressView) {
    let Alert = UIAlertController(title: Title, message: Message, preferredStyle: .alert)
    let ProgressView = UIProgressView(progressViewStyle: .default)
    ProgressView.SetProgress(0)
    ProgressView.frame = CGRect(x: 10, y: 50, width: 250, height: 0)
    Alert.view.addSubview(ProgressView)
    PresentView(Alert)
    return (Alert, ProgressView)
}

extension UIProgressView {
    func SetProgress(_ Progress: Float, _ Total: Float = 1, _ Animated: Bool = true) {
        DispatchQueue.main.async {
            self.setProgress(Progress / Total, animated: Animated)
        }
    }
}

func ShowAlert(_ Title: String, _ Message: String) {
    if let _ = RootVC?.presentedViewController as? UIAlertController {
        DismissView(false)
        Thread.sleep(forTimeInterval: 0.5)
    }
    let Alert = UIAlertController(title: Title, message: Message, preferredStyle: .alert)
    Alert.AddDoneButton()
    PresentView(Alert)
}

func PresentView(_ View: UIViewController) {
    DispatchQueue.main.async {
        RootVC?.present(View, animated: true)
    }
}

func DismissView(_ Animated: Bool = true) {
    DispatchQueue.main.async {
        RootVC?.dismiss(animated: Animated)
    }
}

extension UIAlertController {
    func SetTitle(_ Title: String) {
        DispatchQueue.main.async {
            self.title = Title
        }
    }
    func AddDoneButton() {
        DispatchQueue.main.async {
            self.addAction(UIAlertAction(title: "Done", style: .cancel))
        }
    }
}
