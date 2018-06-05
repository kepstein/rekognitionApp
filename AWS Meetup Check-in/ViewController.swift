//
//  ViewController.swift
//  camera_tutorial
//
//  Created by Zephaniah Cohen on 1/14/17.
//  Copyright © 2017 CodePro. All rights reserved.
//

import UIKit
//import AWSCore
import AWSRekognition
import AWSCognito
import AWSDynamoDB
import SwiftyJSON
import Alamofire


class ViewController: UIViewController {
    
    
//    @IBOutlet weak var imageView: UIImageView!
//    @IBOutlet weak var confidenceButton: UIButton!
    @IBOutlet weak var buttonView: RoundButton!
    @IBOutlet weak var rsvpName: UITextField!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    var memberId : String = ""
    
    let pickerController = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        pickerController.sourceType = UIImagePickerControllerSourceType.camera
        pickerController.cameraDevice = UIImagePickerControllerCameraDevice.front
        pickerController.delegate = self
        // https://stackoverflow.com/questions/30067202/camera-flash-turn-auto-on-off-with-uiimagepickercontroller-in-ios-swift
        pickerController.cameraFlashMode = UIImagePickerControllerCameraFlashMode.off
        rsvpName.isUserInteractionEnabled = false
        rsvpName.text = nil
        buttonView.setImage(#imageLiteral(resourceName: "Anonymous"), for: UIControlState.normal)
        activityIndicator.stopAnimating()
        // Do any additional setup after loading the view, typically from a nib.
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func takePicture(_ sender: Any) {
        present(pickerController, animated: true, completion: nil)
    }
    
    @IBAction func resetButtonPress(_ sender: Any) {
        self.rsvpName.text = nil
        buttonView.setImage(#imageLiteral(resourceName: "Anonymous"), for: UIControlState.normal)

    }
    
    func awsAuth() {
        // Set up Cognito for AWS Authentication
        let credentialsProvider = AWSCognitoCredentialsProvider(
            // Insert your correct region information and Cognito identity pool information here
            regionType: .USEast1, identityPoolId: "us-east-1:INSERT-your-own-identity-pool-here")
        
        let configuration = AWSServiceConfiguration(
            region: .USEast1, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
    }
    
    func image2ByteArray(image: UIImage) -> Data? {
        guard let image = UIImage(named: "someImage") else { return nil } // BAIL
        let data = UIImageJPEGRepresentation(image, 0.7)
        return data
    }
    
    func searchFaces(sourceImage: UIImage) {
        
        awsAuth()
        
        // Set up the Recoknition client
        let rekognitionClient = AWSRekognition.default()
        let image = AWSRekognitionImage()
        image!.bytes = UIImageJPEGRepresentation(sourceImage, 0.7)
        
        // Instantiate the request
        guard let request = AWSRekognitionSearchFacesByImageRequest() else {
            puts("Unable to initialize AWSRekognitionSearchFacesByImageRequest.")
            return
        }
        
        // Set up request parameters
        request.image = image // the byta array
        request.collectionId = "my-rekognotion-collection-id" // the image collection
        request.faceMatchThreshold = 75 // This is how we tune to avoid false positives / false negatives. 
        request.maxFaces = 1 // max number of faces to return as a match
        
        // Rekognition client sends the image byte array, and searched the image collection
        rekognitionClient.searchFaces(byImage:request) { (response:AWSRekognitionSearchFacesByImageResponse?, error:Error?) in
            if error == nil
            {
                // We detected a face in the image
                let faces_count = response?.faceMatches?.count ?? 0
                
                if faces_count != 1 {
                    // We detected a face in the photo we took, but could not match the face with faces indexed in the collection.
                    print("No match")
                    DispatchQueue.main.async {
                        self.rsvpName.text = "No match"
                        self.activityIndicator.stopAnimating()
                    }
                    
                } else {
                    // We detected a face in the photo and were able to match it with a face indexed in the collection
                    
                    let matchName = response!.faceMatches?[0].face?.externalImageId!
                    // let confidence = response!.faceMatches?[0].face?.confidence!
                    
                    print(matchName!)
                    DispatchQueue.main.async {
                        self.memberId = matchName!
                        self.getNameFromMemberId(memberId: matchName!)
                        self.activityIndicator.stopAnimating()
                    }
                    
                }
            } else {
                // No faces were detected in the photo we took.
                print("No faces detected")
                DispatchQueue.main.async {
                    self.rsvpName.text = "No faces detected"
                    self.activityIndicator.stopAnimating()
                }
                
            }
            
        }
        
    }
    
    func getNameFromMemberId(memberId : String) {
        
        let url = "https://XXXXXXXXXXXX.execute-api.us-east-1.amazonaws.com/prod/membername"
        let params : [String : String] = [ "id" : memberId ]
        var memberJSON : JSON?
        var memberTemp : String?
        
        Alamofire.request(url, method: .get, parameters: params).responseJSON {
            response in
            if response.result.isSuccess {
                memberJSON = JSON(response.result.value!)
                memberTemp = String(describing: memberJSON!["name"] )
                self.rsvpName.text = memberTemp
                if (memberTemp != nil) {
                    print(memberTemp!)
                }
            }
        }
        
    }
    
    
}

extension ViewController : UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        picker.dismiss(animated: true, completion: nil)
        self.rsvpName.text = "Searching....."
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            buttonView.contentMode = .scaleAspectFill
            buttonView.setImage(pickedImage, for: UIControlState.normal)
            activityIndicator.startAnimating()
            searchFaces(sourceImage: pickedImage)
        }
        
        
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        
        picker.dismiss(animated: true)
        
    }
    
}

extension ViewController : UINavigationControllerDelegate {
    
}
