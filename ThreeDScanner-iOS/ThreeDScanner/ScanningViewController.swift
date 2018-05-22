//
//  ScanningViewController.swift
//  ThreeDScanner
//
//  Created by Steven Roach on 11/23/17.
//  Copyright © 2017 Steven Roach. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import GoogleAPIClientForREST
import GoogleSignIn

class ScanningViewController: UIViewController, ARSCNViewDelegate, SCNSceneRendererDelegate, GIDSignInDelegate, GIDSignInUIDelegate {

    // MARK: - Properties
    
    // ARKit / SceneKit
    @IBOutlet var sceneView: ARSCNView!
    private let sessionConfiguration = ARWorldTrackingConfiguration()
    private var pointsParentNode = SCNNode()
    private var surfaceParentNode = SCNNode()
    private lazy var pointMaterial: SCNMaterial = createPointMaterial()
    private var surfaceGeometry: SCNGeometry?
    
    // Dependencies
    private let xyzStringFormatter = XYZStringFormatter()
    private let surfaceExporter = SurfaceExporter()
    private let googleDriveUploader = GoogleDriveUploader()
    
    // Struct to hold currently captured Point Cloud data
    private var pointCloud = PointCloud()
    
    // Scanning Options
    private var isTorchOn = false
    private let addPointRatio = 3 // Show 1 / [addPointRatio] of the points
    private let scanningInterval = 0.5 // Capture points every [scanningInterval] seconds when user is touching screen
    private var isSurfaceDisplayOn = true {
        didSet {
            surfaceParentNode.isHidden = !isSurfaceDisplayOn
        }
    }
    private var isCapturingPoints = false {
        didSet {
            capturePointsButton.isHidden = isCapturingPoints
            pauseCapturePointsButton.isHidden = !isCapturingPoints
        }
    }

    // UI
    private let signInButton = UIButton()
    private let signOutButton = UIButton()
    private let exportButton = UIButton()
    private let uploadPointsButton = UIButton()
    private let capturePointsButton = UIButton()
    private let pauseCapturePointsButton = UIButton()
    
    // Google Sign In
    private var isUserSignedOn = false
    {
        didSet {
            signOutButton.isHidden = !isUserSignedOn
            signInButton.isHidden = isUserSignedOn
            exportButton.isHidden = !isUserSignedOn
            uploadPointsButton.isHidden = !isUserSignedOn
        }
    }
    

    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Configure Google Sign-in.
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().scopes = ["https://www.googleapis.com/auth/drive"]
        GIDSignIn.sharedInstance().signInSilently()
        
        // Add buttons
        addCapturePointsButton()
        addPauseCapturePointsButton()
        addReconstructButton()
        addTorchSwitch()
        addTorchLabel()
        addResetButton()
        addDisplaySurfaceSwitch()
        addIsSurfaceDisplayedLabel()
        addExportButton()
        addSignInButton()
        addSignOutButton()
        
        // Add SceneKit Parent Nodes
        sceneView.scene.rootNode.addChildNode(pointsParentNode)
        sceneView.scene.rootNode.addChildNode(surfaceParentNode)
        
        // Set SceneKit Lighting
        sceneView.autoenablesDefaultLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set Session configuration
        sessionConfiguration.planeDetection = ARWorldTrackingConfiguration.PlaneDetection.horizontal
        
        // Run the view's session
        sceneView.session.run(sessionConfiguration)
        
        // Show feature points and world origin
        sceneView.debugOptions.insert(ARSCNDebugOptions.showFeaturePoints)
        
        scheduledTimerWithTimeInterval()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
        print("Memory Warning")
    }
    
    
    // MARK: - Timer
    
    var timer = Timer()
    
    func scheduledTimerWithTimeInterval() {
        // Scheduling timer to call the function "updateCounting" every [scanningInteval] seconds
        timer = Timer.scheduledTimer(timeInterval: scanningInterval, target: self, selector: #selector(updateCounting), userInfo: nil, repeats: true)
    }
    
    @objc func updateCounting() {
        if isCapturingPoints {
            capturePoints()
        }
    }

    
    // MARK: - UI
    
    private func addCapturePointsButton() {
        view.addSubview(capturePointsButton)
        capturePointsButton.translatesAutoresizingMaskIntoConstraints = false
        capturePointsButton.setTitle("Scan", for: .normal)
        capturePointsButton.setTitleColor(UIColor.red, for: .normal)
        capturePointsButton.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        capturePointsButton.layer.cornerRadius = 4
        capturePointsButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        capturePointsButton.addTarget(self, action: #selector(toggleIsCapturingPoints(sender:)) , for: .touchUpInside)
        
        // Contraints
        capturePointsButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50.0).isActive = true
        capturePointsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0).isActive = true
        capturePointsButton.heightAnchor.constraint(equalToConstant: 50)
    }
    
    private func addPauseCapturePointsButton() {
        pauseCapturePointsButton.isHidden = true
        view.addSubview(pauseCapturePointsButton)
        pauseCapturePointsButton.translatesAutoresizingMaskIntoConstraints = false
        pauseCapturePointsButton.setTitle("Pause Scanning", for: .normal)
        pauseCapturePointsButton.setTitleColor(UIColor.red, for: .normal)
        pauseCapturePointsButton.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        pauseCapturePointsButton.layer.cornerRadius = 4
        pauseCapturePointsButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        pauseCapturePointsButton.addTarget(self, action: #selector(toggleIsCapturingPoints(sender:)) , for: .touchUpInside)
        
        // Contraints
        pauseCapturePointsButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50.0).isActive = true
        pauseCapturePointsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0).isActive = true
        pauseCapturePointsButton.heightAnchor.constraint(equalToConstant: 50)
    }
    
    private func addReconstructButton() {
        let reconstructButton = UIButton()
        view.addSubview(reconstructButton)
        reconstructButton.translatesAutoresizingMaskIntoConstraints = false
        reconstructButton.setTitle("Reconstruct", for: .normal)
        reconstructButton.setTitleColor(UIColor.red, for: .normal)
        reconstructButton.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        reconstructButton.layer.cornerRadius = 4
        reconstructButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        reconstructButton.addTarget(self, action: #selector(reconstructButtonTapped(sender:)) , for: .touchUpInside)
        
        // Contraints
        reconstructButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8.0).isActive = true
        reconstructButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0).isActive = true
        reconstructButton.heightAnchor.constraint(equalToConstant: 50)
    }
    
    private func addTorchSwitch() {
        let torchSwitch = UISwitch()
        view.addSubview(torchSwitch)
        torchSwitch.translatesAutoresizingMaskIntoConstraints = false
        torchSwitch.isOn = isTorchOn
        torchSwitch.setOn(isTorchOn, animated: false)
        torchSwitch.addTarget(self, action: #selector(torchSwitchValueDidChange(sender:)), for: .valueChanged)
        
        // Contraints
        torchSwitch.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8.0).isActive = true
        torchSwitch.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -14.0).isActive = true
        torchSwitch.heightAnchor.constraint(equalToConstant: 50)
    }
    
    private func addTorchLabel() {
        let torchLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))
        view.addSubview(torchLabel)
        torchLabel.translatesAutoresizingMaskIntoConstraints = false
        torchLabel.textAlignment = .center
        torchLabel.text = "Flashlight"
        torchLabel.font = UIFont.systemFont(ofSize: 10.0)
        
        // Contraints
        torchLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40.0).isActive = true
        torchLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -14.0).isActive = true
        torchLabel.heightAnchor.constraint(equalToConstant: 50)
    }
    
    private func addResetButton() {
        let resetButton = UIButton()
        view.addSubview(resetButton)
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.setTitle("Reset Scan", for: .normal)
        resetButton.setTitleColor(UIColor.red, for: .normal)
        resetButton.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        resetButton.layer.cornerRadius = 4
        resetButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        resetButton.addTarget(self, action: #selector(resetButtonTapped(sender:)) , for: .touchUpInside)
        
        // Contraints
        resetButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 20.0).isActive = true
        resetButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0.0).isActive = true
        resetButton.heightAnchor.constraint(equalToConstant: 50)
    }
    
    private func addDisplaySurfaceSwitch() {
        let displaySurfaceSwitch = UISwitch()
        view.addSubview(displaySurfaceSwitch)
        displaySurfaceSwitch.translatesAutoresizingMaskIntoConstraints = false
        displaySurfaceSwitch.isOn = isSurfaceDisplayOn
        displaySurfaceSwitch.setOn(isSurfaceDisplayOn, animated: false)
        displaySurfaceSwitch.addTarget(self, action: #selector(displaySurfaceSwitchValueDidChange(sender:)), for: .valueChanged)
        
        // Contraints
        displaySurfaceSwitch.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8.0).isActive = true
        displaySurfaceSwitch.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 14.0).isActive = true
        displaySurfaceSwitch.heightAnchor.constraint(equalToConstant: 50)
    }
    
    private func addIsSurfaceDisplayedLabel() {
        let isSurfaceDisplayedLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))
        view.addSubview(isSurfaceDisplayedLabel)
        isSurfaceDisplayedLabel.translatesAutoresizingMaskIntoConstraints = false
        isSurfaceDisplayedLabel.textAlignment = .center
        isSurfaceDisplayedLabel.text = "Display Surface"
        isSurfaceDisplayedLabel.font = UIFont.systemFont(ofSize: 10.0)
        
        // Contraints
        isSurfaceDisplayedLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40.0).isActive = true
        isSurfaceDisplayedLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 4.0).isActive = true
        isSurfaceDisplayedLabel.heightAnchor.constraint(equalToConstant: 50)
    }
    
    private func addExportButton() {
        view.addSubview(exportButton)
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        exportButton.setTitle("Export", for: .normal)
        exportButton.setTitleColor(UIColor.red, for: .normal)
        exportButton.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        exportButton.layer.cornerRadius = 4
        exportButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        exportButton.addTarget(self, action: #selector(exportButtonTapped(sender:)) , for: .touchUpInside)
        
        // Contraints
        exportButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 20.0).isActive = true
        exportButton.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 8.0).isActive = true
        exportButton.heightAnchor.constraint(equalToConstant: 50)
    }
    
    private func addSignInButton() {
        view.addSubview(signInButton)
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        signInButton.setTitle("Sign In", for: .normal)
        signInButton.setTitleColor(UIColor.red, for: .normal)
        signInButton.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        signInButton.layer.cornerRadius = 4
        signInButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        signInButton.addTarget(self, action: #selector(signInButtonTapped(sender:)) , for: .touchUpInside)
        
        // Contraints
        signInButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 20.0).isActive = true
        signInButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -8.0).isActive = true
        signInButton.heightAnchor.constraint(equalToConstant: 50)
    }
    
    private func addSignOutButton() {
        view.addSubview(signOutButton)
        signOutButton.translatesAutoresizingMaskIntoConstraints = false
        signOutButton.setTitle("Sign Out", for: .normal)
        signOutButton.setTitleColor(UIColor.red, for: .normal)
        signOutButton.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        signOutButton.layer.cornerRadius = 4
        signOutButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        signOutButton.addTarget(self, action: #selector(signOutButtonTapped(sender:)) , for: .touchUpInside)
        
        // Contraints
        signOutButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 20.0).isActive = true
        signOutButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -8.0).isActive = true
        signOutButton.heightAnchor.constraint(equalToConstant: 50)
    }
    
    /**
     Displays a standard alert with a title and a message.
     */
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: UIAlertControllerStyle.alert
        )
        alert.addAction(UIAlertAction(
            title: "OK",
            style: UIAlertActionStyle.default,
            handler: nil
        ))
        present(alert, animated: true, completion: nil)
    }
    
    /**
     Creates dialog (as an alert) to let the user specify a file name.
     Dialog has a text field, an enter button, and a cancel button.
     
     Takes a default file name to display and a closure to be called when the enter button is pressed.
     */
    private func createExportFileNameDialog(onEnterExportAction: @escaping (_ fileName: String) throws -> Void,
                                            defaultFileName: String) -> UIAlertController {
        
        let fileNameDialog = UIAlertController(
            title: "File Name",
            message: "Please provide a name for your exported file",
            preferredStyle: UIAlertControllerStyle.alert
        )
        
        fileNameDialog.addTextField(configurationHandler: {(textField: UITextField!) in
            textField.text = defaultFileName
            textField.keyboardType = UIKeyboardType.asciiCapable
        })
        
        // Add Enter Action
        fileNameDialog.addAction(UIAlertAction(
            title: "Enter",
            style: UIAlertActionStyle.default,
            handler: { [weak fileNameDialog] _ in
                do {
                    let fileName = fileNameDialog?.textFields?[0].text ?? defaultFileName
                    try onEnterExportAction(fileName)
                    self.showAlert(title: "Export Success", message: "")
                } catch {
                    self.showAlert(title: "Export Failure", message: "Please try again")
                }
            }
        ))
        
        // Add cancel button
        fileNameDialog.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: { (_) in return }))
        return fileNameDialog
    }
    
    
    // MARK: - UI Actions
    
    @IBAction func toggleIsCapturingPoints(sender: UIButton) {
        isCapturingPoints = !isCapturingPoints
    }
    
    @IBAction func reconstructButtonTapped(sender: UIButton) {
        
        // Prepare Point Cloud data structures in C struct format
        
        let pclPoints = pointCloud.points.map { PCLPoint3D(x: Double($0.x), y: Double($0.y), z: Double($0.z)) }
        let pclViewpoints = pointCloud.frameViewpoints.map { PCLPoint3D(x: Double($0.x), y: Double($0.y), z: Double($0.z)) }
        
        let pclPointCloud = PCLPointCloud(
            numPoints: Int32(pointCloud.points.count),
            points: pclPoints,
            numFrames: Int32(pointCloud.frameViewpoints.count),
            pointFrameLengths: pointCloud.framePointsSizes,
            viewpoints: pclViewpoints)
        
        // Call C++ Surface Reconstruction function using C Wrapper
        let pclMesh = performSurfaceReconstruction(pclPointCloud)
        defer {
            // The mesh points and polygons pointers were allocated in C++ so need to be freed here
            free(pclMesh.points)
            free(pclMesh.polygons)
        }
        
        // Remove current surfaces before displaying new surface
        surfaceParentNode.enumerateChildNodes { (node, stop) in
            node.removeFromParentNode()
            node.geometry = nil
        }
        
        // Display surface
        let surfaceNode = constructSurfaceNode(pclMesh: pclMesh)
        surfaceParentNode.addChildNode(surfaceNode)
        
        showAlert(title: "Surface Reconstructed", message: "\(pclMesh.numFaces) faces")
    }
    
    @IBAction func displaySurfaceSwitchValueDidChange(sender: UISwitch!) {
        isSurfaceDisplayOn = sender.isOn
    }
    
    @IBAction func exportButtonTapped(sender: UIButton) {
       if surfaceGeometry == nil {
            showAlert(title: "No Surface to Export", message: "Press Reconstruct Surface and then export.")
            return
        }
        let fileNameDialog = createExportFileNameDialog(onEnterExportAction: exportSurfaceAction,
                                                        defaultFileName: ScanningConstants.defaultSurfaceExportFileName)
        self.present(fileNameDialog, animated: true, completion: nil)
    }
    
    @IBAction func resetButtonTapped(sender: UIButton) {
        
        pointCloud.points = []
        pointCloud.framePointsSizes = []
        pointCloud.frameViewpoints = []

        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in node.removeFromParentNode() }

        pointsParentNode = SCNNode()
        surfaceParentNode = SCNNode()
        
        surfaceGeometry = nil

        sceneView.scene.rootNode.addChildNode(pointsParentNode)
        sceneView.scene.rootNode.addChildNode(surfaceParentNode)

        sceneView.debugOptions.remove(ARSCNDebugOptions.showFeaturePoints)
        sceneView.debugOptions.remove(ARSCNDebugOptions.showWorldOrigin)
        
        // Run the view's session
        sceneView.session.run(sessionConfiguration, options: [ARSession.RunOptions.resetTracking, ARSession.RunOptions.removeExistingAnchors])
        
        sceneView.debugOptions.insert(ARSCNDebugOptions.showFeaturePoints)
        sceneView.debugOptions.insert(ARSCNDebugOptions.showWorldOrigin)
    }
    
    @IBAction func torchSwitchValueDidChange(sender: UIButton) {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else {
            return
        }
        
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                
                if !isTorchOn {
                    device.torchMode = .on
                    try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                } else {
                    device.torchMode = .off
                }
                isTorchOn = !isTorchOn
                
                device.unlockForConfiguration()
            } catch {
                print("Torch could not be used")
            }
        } else {
            print("Torch is not available")
        }
    }
        
    @IBAction func signInButtonTapped(sender: UIButton) {
        GIDSignIn.sharedInstance().signIn()
    }
    
    @IBAction func signOutButtonTapped(sender: UIButton) {
        GIDSignIn.sharedInstance().signOut()
        GoogleDriveLogin.sharedInstance.service.authorizer = nil
        isUserSignedOn = false
    }
    
    /**
     Called as part of GIDSignInDelegate.
     */
    internal func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if let error = error {
            showAlert(title: "Authentication Error", message: error.localizedDescription)
            GoogleDriveLogin.sharedInstance.service.authorizer = nil
            isUserSignedOn = false
        } else {
            GoogleDriveLogin.sharedInstance.service.authorizer = user.authentication.fetcherAuthorizer()
            isUserSignedOn = true
        }
    }
    
    /**
     Exports the surface to a Data file and uploads to Google Drive.
     Function to be called when user presses enter after clicking upload points.
     */
    private func exportSurfaceAction(fileName: String) throws {
        guard let surfaceGeometry = surfaceGeometry else {
            return
        }
        
        // Now that we have a file name, we can export the surface to a data file
        let surfaceData = try self.surfaceExporter.exportSurface(
            withGeometry: surfaceGeometry,
            fileNamed: fileName,
            withExtension: ScanningConstants.surfaceExportFileExtension)
        
        // Upload Data File to Google Drive
        try self.googleDriveUploader.uploadDataFile(
            fileData: surfaceData,
            name: fileName,
            fileExtension: ScanningConstants.surfaceExportFileExtension)
        self.showAlert(title: "Upload Success", message: "")
    }
    
    
    // MARK: - Helper Functions
    
    private func capturePoints() {
        
        // Store Points
        guard let rawFeaturePoints = sceneView.session.currentFrame?.rawFeaturePoints else {
            return
        }
        let currentPoints = rawFeaturePoints.points
        pointCloud.points += currentPoints
        pointCloud.framePointsSizes.append(Int32(currentPoints.count))
        
        // Display points
        var i = 0
        for rawPoint in currentPoints {
            if i % addPointRatio == 0 {
                addPointToView(position: rawPoint)
            }
            i += 1
        }
        
        // Add viewpoint
        let camera = sceneView.session.currentFrame?.camera
        if let transform = camera?.transform {
            let position = SCNVector3(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )
            pointCloud.frameViewpoints.append(position)
        }
    }
    
    /**
     Constructs an SCNNode representing the given PCL surface mesh output.
     */
    private func constructSurfaceNode(pclMesh: PCLMesh) -> SCNNode {
        
        // Construct vertices array
        var vertices = [SCNVector3]()
        for i in 0..<pclMesh.numPoints {
            vertices.append(SCNVector3(x: Float(pclMesh.points[i].x),
                                       y: Float(pclMesh.points[i].y),
                                       z: Float(pclMesh.points[i].z)))
        }
        let vertexSource = SCNGeometrySource(vertices: vertices)
        
        // Construct elements array
        var elements = [SCNGeometryElement]()
        for i in 0..<pclMesh.numFaces {
            let allPrimitives: [Int32] = [pclMesh.polygons[i].v1, pclMesh.polygons[i].v2, pclMesh.polygons[i].v3]
            elements.append(SCNGeometryElement(indices: allPrimitives, primitiveType: .triangles))
        }
        
        // Set surfaceGeometry to object from vertex and element data
        surfaceGeometry = SCNGeometry(sources: [vertexSource], elements: elements)
        surfaceGeometry?.firstMaterial?.isDoubleSided = true;
        surfaceGeometry?.firstMaterial?.diffuse.contents =
            UIColor(displayP3Red: 135/255, green: 206/255, blue: 250/255, alpha: 1)
        surfaceGeometry?.firstMaterial?.lightingModel = .blinn
        return SCNNode(geometry: surfaceGeometry)
    }
    
    /**
     Creates a the SCNMaterial to be used for points in the displayed Point Cloud.
     */
    private func createPointMaterial() -> SCNMaterial {
        let textureImage = #imageLiteral(resourceName: "WhiteBlack")
        UIGraphicsBeginImageContext(textureImage.size)
        let width = textureImage.size.width
        let height = textureImage.size.height
        textureImage.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        let pointMaterialImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        let pointMaterial = SCNMaterial()
        pointMaterial.diffuse.contents = pointMaterialImage
        return pointMaterial
    }
    
    /**
     Helper function to add points to the view at the given position.
     */
    private func addPointToView(position: vector_float3) {
        let sphere = SCNSphere(radius: 0.00066)
        sphere.segmentCount = 8
        sphere.firstMaterial = pointMaterial

        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.orientation = (sceneView.pointOfView?.orientation)!
        sphereNode.pivot = SCNMatrix4MakeRotation(-Float.pi / 2, 0, 1, 0)
        sphereNode.position = SCNVector3(position)
        pointsParentNode.addChildNode(sphereNode)
    }
}