//
//  ViewController.swift
//  FlickFinder
//
//  Created by Jarrod Parkes on 11/5/15.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - ViewController: UIViewController

class ViewController: UIViewController {
    
    // MARK: Properties
    
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var photoTitleLabel: UILabel!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var phraseSearchButton: UIButton!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var latLonSearchButton: UIButton!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        phraseTextField.delegate = self
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
        
        // SEE
        subscribeToNotification(.UIKeyboardWillShow, selector: #selector(keyboardWillShow))
        subscribeToNotification(.UIKeyboardWillHide, selector: #selector(keyboardWillHide))
        subscribeToNotification(.UIKeyboardDidShow, selector: #selector(keyboardDidShow))
        subscribeToNotification(.UIKeyboardDidHide, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications() // SEE
    }
    
    // MARK: Search Actions
    
    @IBAction func searchByPhrase(_ sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if !phraseTextField.text!.isEmpty {
            photoTitleLabel.text = "Searching..."

            let methodParameters = [Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,Constants.FlickrParameterKeys.Text: phraseTextField.text!, Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL, Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey, Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod, Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat, Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback] as [String: AnyObject]
        
            displayImageFromFlickrBySearch(methodParameters)
        } else {
            setUIEnabled(true)
            photoTitleLabel.text = "Phrase Empty."
        }
    }
    
    @IBAction func searchByLatLon(_ sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        // See the method. Note that Constants.... is a tuple. tuples are indexed by tupleName.0 so on
        
        if isTextFieldValid(latitudeTextField, forRange: Constants.Flickr.SearchLatRange) && isTextFieldValid(longitudeTextField, forRange: Constants.Flickr.SearchLonRange) {
            photoTitleLabel.text = "Searching..."
            
            let methodParameters = [Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,Constants.FlickrParameterKeys.BoundingBox: bboxString(), Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL, Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey, Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod, Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat, Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback] as [String: AnyObject]
            
            displayImageFromFlickrBySearch(methodParameters)
        }
        else {
            setUIEnabled(true)
            photoTitleLabel.text = "Lat should be [-90, 90].\nLon should be [-180, 180]."
        }
    }
    
    private func bboxString() -> String {
        return "\(max(Double(longitudeTextField.text!)! - Constants.Flickr.SearchBBoxHalfHeight, Double(Constants.Flickr.SearchLonRange.0))),\(max(Double(latitudeTextField.text!)! - Constants.Flickr.SearchBBoxHalfWidth, Double(Constants.Flickr.SearchLatRange.0))),\(min(Double(longitudeTextField.text!)! + Constants.Flickr.SearchBBoxHalfHeight, Double(Constants.Flickr.SearchLonRange.1))),\(min(Double(latitudeTextField.text!)! + Constants.Flickr.SearchBBoxHalfWidth, Double(Constants.Flickr.SearchLatRange.1)))"
    }
    // MARK: Flickr API
    
    // the URLComponents class - build URLs in a piecewise fashion. Better solution to deal with unsafe, escape characters than the way we used before:
    // 
    // https://udacity.com/nanodegree
    // 
    // https is the scheme - specifies the protocl we are using
    // udacity.com is the hostname - tells us where the server is located
    // nanodegree is the path - specifies the location on the server that the resource we want is located
    // 
    // let components = URLComponents()
    // components.scheme = "https"
    // components.hostname = "udacity.com"
    // components.path = "/nanodegree"
    // print(components.url)
    //
    // var components = URLComponents()
    // components.scheme = "https"
    // components.host = "api.flickr.com"
    // components.path = "/services/rest
    
    // all the stuff after than is query - "method=....&api_key=..."
    
    // let queryItem1 = URLQueryItem(name: "method", value: "flickr.photos.search")
    // components.queryItems!.append(queryItem1) // see that queryItems in an array in that class and we can just append it
    
    // note that the '?' isn't part of the query or the path.
    
    // note the we can skip 'www' but not something like 'api' in 'api.flickr'
    
    private func displayImageFromFlickrBySearch(_ methodParameters: [String: AnyObject]) {
        
        let url = URLRequest(url: flickrURLFromParameters(methodParameters))
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            
            func displayError(_ error: String) {
                print(error)
                print("URL at time of error: \(url)")
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.photoTitleLabel.text = "No image was returned. Try again"
                }
            }

            /* GUARD: Was there an error? */
            guard (error == nil) else {
                displayError("There was an error with your request: \(String(describing: error))")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                displayError("Your request returned a status code other than 2xx!")
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                displayError("No data was returned by the request!")
                return
            }
            
            // parse the data
            let parsedResult: [String:AnyObject]!
            do {
                parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                displayError("Could not parse the data as JSON: '\(data)'")
                return
            }
            
            /* GUARD: Did Flickr return an error (stat != ok)? */
            guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String, stat == Constants.FlickrResponseValues.OKStatus else {
                displayError("Flickr API returned an error. See error code and message in \(parsedResult)")
                return
            }
            
            /* GUARD: Are the "photos" and "photo" keys in our result? */
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject], let numOfPages = photosDictionary[Constants.FlickrResponseKeys.Pages] as? Int else {
                displayError("Cannot find keys '\(Constants.FlickrResponseKeys.Photos)' and '\(Constants.FlickrResponseKeys.Pages)'")
                return
            }
            
            // select a random photo
            
            // But our previos app wasn't really random. If you look at the API, several pages of data are returned and one of the URL query items is the page number you want to choose from. The API also limits the number of results returned in total (in all pages). So we first make a request to find out how many pages there are, then select a random page number. Then make a second request to that page.
            
            // When working with networking requests, requests don't complete instantly. That's why a completion handler is used - I dont know when the request will complete, but when it does do this...
            
            // While the networking request is processing, our app keeps on running. Such a request is an ASYNCHRONOS REQUEST - the exceution of code in completetion block is deferred until the request completes. You can chain several asynchronos requests together - by putting one inside the completion handlr of the other.
           
            let randomPageIndex = Int(arc4random_uniform(UInt32(numOfPages))) + 1 // +1 is important!!
            
            // remeber than swift formal params are constants! methodParameters[Constants.FlickrParameterKeys.Page] = randomPageIndex
            var methodParametersForAsynchRequest = methodParameters
            methodParametersForAsynchRequest[Constants.FlickrParameterKeys.Page] = randomPageIndex as AnyObject
            
            print("\(numOfPages) \(randomPageIndex)")
            
            let url = URLRequest(url: self.flickrURLFromParameters(methodParametersForAsynchRequest)) // note than self is required here
            let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
                
                /* GUARD: Was there an error? */
                guard (error == nil) else {
                    displayError("There was an error with your request: \(String(describing: error))")
                    return
                }
                
                /* GUARD: Did we get a successful 2XX response? */
                guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                    displayError("Your request returned a status code other than 2xx!")
                    return
                }
                
                /* GUARD: Was there any data returned? */
                guard let data = data else {
                    displayError("No data was returned by the request!")
                    return
                }
                
                // parse the data
                let parsedResult: [String:AnyObject]!
                do {
                    parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
                } catch {
                    displayError("Could not parse the data as JSON: '\(data)'")
                    return
                }
                
                /* GUARD: Did Flickr return an error (stat != ok)? */
                guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String, stat == Constants.FlickrResponseValues.OKStatus else {
                    displayError("Flickr API returned an error. See error code and message in \(parsedResult)")
                    return
                }
                
                /* GUARD: Are the "photos" and "photo" keys in our result? */
                guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String:AnyObject], let photoArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as? [[String:AnyObject]], let pageExists = photosDictionary[Constants.FlickrResponseKeys.Page] as? Int else {
                    displayError("Cannot find keys '\(Constants.FlickrResponseKeys.Photos)' and '\(Constants.FlickrResponseKeys.Photo)' in \(parsedResult) and '\(Constants.FlickrResponseKeys.Page)'")
                    return
                }
                
                guard (pageExists == randomPageIndex) else {
                    displayError("Could not get results from a randommly selected page number")
                    return
                }
                
                // select a random photo
                let randomPhotoIndex = Int(arc4random_uniform(UInt32(photoArray.count)))
                let photoDictionary = photoArray[randomPhotoIndex] as [String:AnyObject]
                let photoTitle = photoDictionary[Constants.FlickrResponseKeys.Title] as? String
                
                /* GUARD: Does our photo have a key for 'url_m'? */
                guard let imageUrlString = photoDictionary[Constants.FlickrResponseKeys.MediumURL] as? String else {
                    displayError("Cannot find key '\(Constants.FlickrResponseKeys.MediumURL)' in \(photoDictionary)")
                    return
                }
                
                // if an image exists at the url, set the image and title
                let imageURL = URL(string: imageUrlString)
                if let imageData = try? Data(contentsOf: imageURL!) {
                    performUIUpdatesOnMain {
                        self.setUIEnabled(true)
                        self.photoImageView.image = UIImage(data: imageData)
                        self.photoTitleLabel.text = photoTitle ?? "(Untitled)"
                    }
                } else {
                    displayError("Image does not exist at \(String(describing: imageURL))")
                }
                
            }
            task.resume()
        }
        task.resume()
    }
    
    // MARK: Helper for Creating a URL from Parameters
    
    private func flickrURLFromParameters(_ parameters: [String: AnyObject]) -> URL {
        
        var components = URLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [URLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = URLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        return components.url!
    }
}

// MARK: - ViewController: UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate, this is why we...
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(_ notification: Notification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
        }
    }
    
    func keyboardWillHide(_ notification: Notification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
        }
    }
    
    func keyboardDidShow(_ notification: Notification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(_ notification: Notification) {
        keyboardOnScreen = false
    }
    
    func keyboardHeight(_ notification: Notification) -> CGFloat {
        let userInfo = (notification as NSNotification).userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.cgRectValue.height
    }
    
    // see these methods
    func resignIfFirstResponder(_ textField: UITextField) {
        if textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }
    
    // basically, if any of the text fields were focused on when the user 'searched', then resign first responder
    // see the storyboard as well. it is connected to Tap Gesture View, if the user taps anywhere on the view, keyboard goes down
    @IBAction func userDidTapView(_ sender: AnyObject) {
        resignIfFirstResponder(phraseTextField)
        resignIfFirstResponder(latitudeTextField)
        resignIfFirstResponder(longitudeTextField)
    }
    
    // MARK: TextField Validation
    
    func isTextFieldValid(_ textField: UITextField, forRange: (Double, Double)) -> Bool {
        if let value = Double(textField.text!), !textField.text!.isEmpty {
            return isValueInRange(value, min: forRange.0, max: forRange.1)
        } else {
            return false
        }
    }
    
    func isValueInRange(_ value: Double, min: Double, max: Double) -> Bool {
        return !(value < min || value > max)
    }
}

// MARK: - ViewController (Configure UI)

private extension ViewController {
    
     func setUIEnabled(_ enabled: Bool) {
        photoTitleLabel.isEnabled = enabled
        phraseTextField.isEnabled = enabled
        latitudeTextField.isEnabled = enabled
        longitudeTextField.isEnabled = enabled
        phraseSearchButton.isEnabled = enabled
        latLonSearchButton.isEnabled = enabled
        
        // adjust search button alphas
        if enabled {
            phraseSearchButton.alpha = 1.0
            latLonSearchButton.alpha = 1.0
        } else { // see alpha values
            phraseSearchButton.alpha = 0.5
            latLonSearchButton.alpha = 0.5
        }
    }
}

// MARK: - ViewController (Notifications)

private extension ViewController {
    
    func subscribeToNotification(_ notification: NSNotification.Name, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    func unsubscribeFromAllNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}
