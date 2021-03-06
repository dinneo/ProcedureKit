//
//  ProcedureKit
//
//  Copyright © 2016 ProcedureKit. All rights reserved.
//

import XCTest
import MapKit
import ProcedureKit
import TestingProcedureKit
@testable import ProcedureKitLocation

func createLocation(withAccuracy accuracy: CLLocationAccuracy = 10) -> CLLocation {
    return CLLocation(
        coordinate: CLLocationCoordinate2DMake(0.0, 0.0),
        altitude: 100,
        horizontalAccuracy: accuracy,
        verticalAccuracy: accuracy,
        course: 0,
        speed: 0,
        timestamp: Date()
    )
}

func createPlacemark(coordinate: CLLocationCoordinate2D) -> CLPlacemark {
    return MKPlacemark(coordinate: coordinate, addressDictionary: ["City": "London"])
}

class TestableLocationServicesRegistrar {
    static let fake = CLLocationManager()

    weak var delegate: CLLocationManagerDelegate? = nil
    var servicesEnabled = true
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var responseStatus: CLAuthorizationStatus = .authorizedAlways

    var didCheckServiceEnabled = false
    var didCheckAuthorizationStatus = false
    var didSetDelegate = false
    var didRequestAuthorization = false
    var didRequestAuthorizationForUsage: LocationUsage? = nil
}

extension TestableLocationServicesRegistrar: LocationServicesRegistrarProtocol {

    func pk_locationServicesEnabled() -> Bool {
        didCheckServiceEnabled = true
        return servicesEnabled
    }

    func pk_authorizationStatus() -> CLAuthorizationStatus {
        didCheckAuthorizationStatus = true
        return authorizationStatus
    }

    func pk_set(delegate aDelegate: CLLocationManagerDelegate?) {
        didSetDelegate = true
        delegate = aDelegate
    }

    func pk_requestAuthorization(withRequirement requirement: LocationUsage?) {
        didRequestAuthorization = true
        didRequestAuthorizationForUsage = requirement
        // In some cases CLLocationManager will immediately send a .NotDetermined
        delegate?.locationManager!(TestableLocationServicesRegistrar.fake, didChangeAuthorization: .notDetermined)
        delegate?.locationManager!(TestableLocationServicesRegistrar.fake, didChangeAuthorization: responseStatus)
    }
}

class TestableLocationManager: TestableLocationServicesRegistrar {

    var returnedLocation: CLLocation? = nil
    var returnedError: Error? = nil
    var returnAfterDelay: TimeInterval = 0.001

    var didSetDesiredAccuracy: CLLocationAccuracy? = nil
    var didStartUpdatingLocation = false
    var didStopUpdatingLocation = false
}

extension TestableLocationManager: LocationServicesProtocol {

    func pk_set(desiredAccuracy: CLLocationAccuracy) {
        didSetDesiredAccuracy = desiredAccuracy
    }

    func pk_startUpdatingLocation() {
        didStartUpdatingLocation = true
        if let error = returnedError {
            delegate?.locationManager!(TestableLocationServicesRegistrar.fake, didFailWithError: error)
        }
        else {
            DispatchQueue.main.asyncAfter(deadline: .now() + returnAfterDelay) {
                self.delegate?.locationManager!(TestableLocationServicesRegistrar.fake, didUpdateLocations: self.returnedLocation.flatMap { [$0] } ?? [])
            }
        }
    }

    func pk_stopUpdatingLocation() {
        didStopUpdatingLocation = true
    }
}

class TestableGeocoder: GeocodeProtocol {

    var didCancel = false

    func pk_cancel() {
        didCancel = true
    }
}

class TestableReverseGeocoder: TestableGeocoder, ReverseGeocodeProtocol {

    var didReverseGeocodeLocation: CLLocation? = nil

    var placemarks: [CLPlacemark]? = nil
    var error: Error? = nil

    func pk_reverseGeocodeLocation(location: CLLocation, completionHandler completion: @escaping CLGeocodeCompletionHandler) {
        didReverseGeocodeLocation = location
        // To replicate CLGeocoder, the completion block must be called on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else {
                fatalError("TestableReverseGeocoder disappeared before completion was called")
            }
            completion(strongSelf.placemarks, strongSelf.error)
        }
    }
}

class LocationProcedureTestCase: ProcedureKitTestCase {

    var location: CLLocation!
    var placemark: CLPlacemark!    
    let accuracy: CLLocationAccuracy = 10
    var manager: TestableLocationManager!
    var geocoder: TestableReverseGeocoder!

    override func setUp() {
        super.setUp()
        location = createLocation(withAccuracy: accuracy)
        placemark = createPlacemark(coordinate: location.coordinate)
        manager = TestableLocationManager()
        manager.authorizationStatus = .authorizedAlways
        manager.returnedLocation = location
        geocoder = TestableReverseGeocoder()
    }

    override func tearDown() {
        location = nil
        manager = nil
        geocoder = nil
        super.tearDown()
    }
}


