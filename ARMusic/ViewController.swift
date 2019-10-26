//
//  ViewController.swift
//  ARMusic
//
//  Created by Valerian Clerc on 10/26/19.
//  Copyright © 2019 Valerian Clerc. All rights reserved.
//

import UIKit
import ARKit
import SceneKit
import CoreLocation

class ViewController: UIViewController, ARSCNViewDelegate, CLLocationManagerDelegate {
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var statusTextView: UITextView!
    
    let locationManager = CLLocationManager()
    var userLocation = CLLocation()
    
    var heading : Double! = 0.0
    var distance : Float! = 0.0 {
      didSet {
        setStatusText()
      }
    }
    var status: String! {
      didSet {
        setStatusText()
      }
    }

    func setStatusText() {
      var text = "Status: \(status!)\n"
      text += "Distance: \(String(format: "%.2f m", distance))"
      statusTextView.text = text
    }
    
    var modelNode:SCNNode!
    let rootNodeName = "Note"
    var originalTransform:SCNMatrix4!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self

        // Create a new scene
        let scene = SCNScene()

        // Set the scene to the view
        sceneView.scene = scene

        // Start location services
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()

        // Set the initial status
        status = "Getting user location..."

        // Set a padding in the text view
        statusTextView.textContainerInset = UIEdgeInsets(top: 20.0, left: 10.0, bottom: 10.0, right: 0.0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Pause the view's session
        sceneView.session.pause()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Implementing this method is required
        print(error.localizedDescription)
    }

    func locationManager(_ manager: CLLocationManager,
          didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            locationManager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager,
          didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
          userLocation = location
          status = "Connecting to Pusher..."

//          self.connectToPusher()
        }
    }
    
    func updateLocation(_ latitude : Double, _ longitude : Double) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        self.distance = Float(location.distance(from: self.userLocation))
        if self.modelNode == nil {
            let modelScene = SCNScene(named: "art.scnassets/Car.dae")!
            self.modelNode = modelScene.rootNode.childNode(withName: rootNodeName, recursively: true)!
            // Move model's pivot to its center in the Y axis
            let (minBox, maxBox) = self.modelNode.boundingBox
            self.modelNode.pivot = SCNMatrix4MakeTranslation(0, (maxBox.y - minBox.y)/2, 0)
            // Save original transform to calculate future rotations
            self.originalTransform = self.modelNode.transform

            // Position the model in the correct place
            positionModel(location)

            // Add the model to the scene
            sceneView.scene.rootNode.addChildNode(self.modelNode)

            // Create arrow from the emoji
            let arrow = makeBillboardNode("⬇️".image()!)
            // Position it on top of the car
            arrow.position = SCNVector3Make(0, 4, 0)
            // Add it as a child of the car model
            self.modelNode.addChildNode(arrow)

        } else {
            // Begin animation
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.0

            // Position the model in the correct place
            positionModel(location)

            // End animation
            SCNTransaction.commit()
        }

        
    }
    
    
    func makeBillboardNode(_ image: UIImage) -> SCNNode {
        let plane = SCNPlane(width: 10, height: 10)
        plane.firstMaterial!.diffuse.contents = image
        let node = SCNNode(geometry: plane)
        node.constraints = [SCNBillboardConstraint()]
        return node
    }
    
    func positionModel(_ location: CLLocation) {
        // Rotate node
        self.modelNode.transform = rotateNode(Float(-1 * (self.heading - 180).toRadians()), self.originalTransform)

        // Translate node
        self.modelNode.position = translateNode(location)

        // Scale node
        self.modelNode.scale = scaleNode(location)
    }
    
    func rotateNode(_ angleInRadians: Float, _ transform: SCNMatrix4) -> SCNMatrix4 {
        let rotation = SCNMatrix4MakeRotation(angleInRadians, 0, 1, 0)
        return SCNMatrix4Mult(transform, rotation)
    }
    
    func scaleNode (_ location: CLLocation) -> SCNVector3 {
        let scale = min( max( Float(1000/distance), 1.5 ), 3 )
        return SCNVector3(x: scale, y: scale, z: scale)
    }
    
    func translateNode (_ location: CLLocation) -> SCNVector3 {
        let locationTransform =
            transformMatrix(matrix_identity_float4x4, userLocation, location)
        return positionFromTransform(locationTransform)
    }

    func positionFromTransform(_ transform: simd_float4x4) -> SCNVector3 {
        return SCNVector3Make(
            transform.columns.3.x, transform.columns.3.y, transform.columns.3.z
        )
    }
    
    func transformMatrix(_ matrix: simd_float4x4, _ originLocation: CLLocation, _ driverLocation: CLLocation) -> simd_float4x4 {
        let bearing = bearingBetweenLocations(userLocation, driverLocation)
        let rotationMatrix = rotateAroundY(matrix_identity_float4x4, Float(bearing))

        let position = vector_float4(0.0, 0.0, -distance, 0.0)
        let translationMatrix = getTranslationMatrix(matrix_identity_float4x4, position)

        let transformMatrix = simd_mul(rotationMatrix, translationMatrix)

        return simd_mul(matrix, transformMatrix)
    }

    func getTranslationMatrix(_ matrix: simd_float4x4, _ translation : vector_float4) -> simd_float4x4 {
        var matrix = matrix
        matrix.columns.3 = translation
        return matrix
    }

    func rotateAroundY(_ matrix: simd_float4x4, _ degrees: Float) -> simd_float4x4 {
        var matrix = matrix

        matrix.columns.0.x = cos(degrees)
        matrix.columns.0.z = -sin(degrees)

        matrix.columns.2.x = sin(degrees)
        matrix.columns.2.z = cos(degrees)
        return matrix.inverse
    }


    func bearingBetweenLocations(_ originLocation: CLLocation, _ driverLocation: CLLocation) -> Double {
        let lat1 = originLocation.coordinate.latitude.toRadians()
        let lon1 = originLocation.coordinate.longitude.toRadians()

        let lat2 = driverLocation.coordinate.latitude.toRadians()
        let lon2 = driverLocation.coordinate.longitude.toRadians()

        let longitudeDiff = lon2 - lon1

        let y = sin(longitudeDiff) * cos(lat2);
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(longitudeDiff);

        return atan2(y, x)
    }

}

