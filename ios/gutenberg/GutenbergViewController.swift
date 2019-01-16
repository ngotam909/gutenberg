
import UIKit
import RNReactNativeGutenbergBridge
import Aztec

class GutenbergViewController: UIViewController {

    fileprivate lazy var gutenberg = Gutenberg(dataSource: self)
    fileprivate var htmlMode = false
    fileprivate var mediaCallback: MediaPickerDidPickMediaToUploadCallback?
    
    override func loadView() {
        view = gutenberg.rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationBar()
        gutenberg.delegate = self
        navigationController?.navigationBar.isTranslucent = false
    }

    @objc func moreButtonPressed(sender: UIBarButtonItem) {
        showMoreSheet()
    }

    @objc func saveButtonPressed(sender: UIBarButtonItem) {
        gutenberg.requestHTML()
    }
}

extension GutenbergViewController: GutenbergBridgeDelegate {
    
    func gutenbergDidLoad() {

    }

    func gutenbergDidProvideHTML(_ html: String, changed: Bool) {
        print("Did receive HTML: \(html) changed: \(changed)")
    }

    func gutenbergDidRequestMediaPicker(with callback: @escaping MediaPickerDidPickMediaCallback) {
        print("Gutenberg did request media picker, passing a sample url in callback")
        callback("https://cldup.com/cXyG__fTLN.jpg")
    }
    
    func gutenbergDidRequestMediaFromDevicePicker(with callback: @escaping MediaPickerDidPickMediaToUploadCallback) {
        print("Gutenberg did request a device media picker, passing a sample url in callback and a fake ID")
        mediaCallback = callback
        let pickerController = UIImagePickerController()
        pickerController.delegate = self
        show(pickerController, sender: nil)
    }
}

extension GutenbergViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
        mediaCallback?(nil, nil)
        mediaCallback = nil
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        dismiss(animated: true, completion: nil)
        let url = URL(fileURLWithPath: NSTemporaryDirectory() + UUID().uuidString + ".jpg")
        guard
            let image = info[UIImagePickerControllerOriginalImage] as? UIImage,
            let data = UIImageJPEGRepresentation(image, 1.0)
        else {
            return
        }
        do {
            try data.write(to: url)
            let mediaID = "1"
            mediaCallback?(url.absoluteString, "1")
            mediaCallback = nil            
            let progress = Progress(parent: nil, userInfo: [ProgressUserInfoKey.mediaID: mediaID, ProgressUserInfoKey.mediaURL: url])
            progress.totalUnitCount = 100
            
            Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(GutenbergViewController.timerFireMethod(_:)), userInfo: progress, repeats: true)
        } catch {
            mediaCallback?(nil, nil)
            mediaCallback = nil
        }
    }
    
    @objc func timerFireMethod(_ timer: Timer) {
        guard let progress = timer.userInfo as? Progress,
            let mediaID = progress.userInfo[.mediaID] as? String,
            let mediaURL = progress.userInfo[.mediaURL] as? URL
            //let otherURL = URL(string: "https://cldup.com/cXyG__fTLN.jpg")
            else {
                timer.invalidate()
                return
        }
        progress.completedUnitCount += 1
        
        if progress.fractionCompleted < 1 {
            gutenberg.mediaUploadUpdate(id: mediaID, state: .uploading, progress: Float(progress.fractionCompleted), url: nil)
        } else if progress.fractionCompleted >= 1 {
            timer.invalidate()
            gutenberg.mediaUploadUpdate(id: mediaID, state: .succeeded, progress: 1, url: mediaURL)
        }
    }
}

extension ProgressUserInfoKey {
    static let mediaID = ProgressUserInfoKey("mediaID")
    static let mediaURL = ProgressUserInfoKey("mediaURL")
}


extension GutenbergViewController: GutenbergBridgeDataSource {
    func gutenbergInitialContent() -> String? {
        return nil
    }

    func aztecAttachmentDelegate() -> TextViewAttachmentDelegate {
        return ExampleAttachmentDelegate()
    }
}

//MARK: - Navigation bar

extension GutenbergViewController {

    func configureNavigationBar() {
        addSaveButton()
        addMoreButton()
    }

    func addSaveButton() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save,
                                                           target: self,
                                                           action: #selector(saveButtonPressed(sender:)))
    }

    func addMoreButton() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "...",
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(moreButtonPressed(sender:)))
    }
}

//MARK: - More actions

extension GutenbergViewController {

    func showMoreSheet() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let cancelAction = UIAlertAction(title: "Keep Editing", style: .cancel)
        alert.addAction(toggleHTMLModeAction)
        alert.addAction(updateHtmlAction)
        alert.addAction(cancelAction)

        present(alert, animated: true)
    }
    
    var toggleHTMLModeAction: UIAlertAction {
        return UIAlertAction(
            title: htmlMode ? "Switch To Visual" : "Switch to HTML",
            style: .default,
            handler: { [unowned self] action in
                self.toggleHTMLMode(action)
        })
    }
    
    var updateHtmlAction: UIAlertAction {
        return UIAlertAction(
            title: "Update HTML",
            style: .default,
            handler: { [unowned self] action in
                let alert = self.alertWithTextInput(using: { [unowned self] (htmlInput) in
                    if let input = htmlInput {
                        self.gutenberg.updateHtml(input)
                    }
                })
                self.present(alert, animated: true, completion: nil)
        })
    }
    
    func alertWithTextInput(using handler: ((String?) -> Void)?) -> UIAlertController {
        let alert = UIAlertController(title: "Enter HTML", message: nil, preferredStyle: .alert)
        alert.addTextField()
        let submitAction = UIAlertAction(title: "Submit", style: .default) { [unowned alert] (action) in
            handler?(alert.textFields?.first?.text)
        }
        alert.addAction(submitAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        return alert
    }
    
    func toggleHTMLMode(_ action: UIAlertAction) {
        htmlMode = !htmlMode
        gutenberg.toggleHTMLMode()
    }
}
