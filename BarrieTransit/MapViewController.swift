//
//  MapViewController.swift
//  BarrieTransit
//
//  Created by Robin on 2015-01-21.
//  Copyright (c) 2015 Huibin Zhao. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    @IBOutlet weak var inputText: UITextField! 
    @IBOutlet weak var busNumTable: UITableView!
    @IBOutlet weak var map: MKMapView!
    
    //Location Data
    let locationManager = CLLocationManager()
    var busNum = [String]()
    var stationLocation = [CLLocationCoordinate2D]()
    let stationRegion = [String:[Double]]()
    var myRoute : MKRoute?
    let busUrlWeekday: [String: String] = {
        return ["1A": ",4", "1B": ",7", "2A": ",10", "2B": ",13", "3A": ",16", "3B": ",19", "4A": ",22", "4B": ",23,26", "5A": ",27,30", "5B": ",33,34,37", "6A": ",40", "6B": ",43", "7A": ",46,49", "7B": ",52,55", "8A": ",58,61,64,67", "8B": ",70,73,76"]
        }()
    let busUrlSat: [String: String] = {
        return ["1A": ",2", "1B": ",5", "2A": ",8", "2B": ",11", "3A": ",14", "3B": ",17", "4A": ",20", "4B": ",24", "5A": ",28", "5B": ",31,35", "6A": ",38", "6B": ",41", "7A": ",44,47", "7B": ",50,53", "8A": ",56,59,62,65", "8B": ",68,71,74"]
        }()
    let busUrlSun: [String: String] = {
        return ["1A": ",3", "1B": ",6", "2A": ",9", "2B": ",12", "3A": ",15", "3B": ",18", "4A": ",21", "4B": ",25", "5A": ",29", "5B": ",32,36", "6A": ",39", "6B": ",42", "7A": ",45,48", "7B": ",51,54", "8A": ",57,60,63,66", "8B": ",69,72,75"]
    }()
    
    let busRegion: [String: CLLocationCoordinate2D] = {
       return ["1A": CLLocationCoordinate2DMake(44.3683936571221, -79.6877596663392),
        "1B": CLLocationCoordinate2DMake(44.3703368256911, -79.6881481091613),
        "2A": CLLocationCoordinate2DMake(44.3568252975666, -79.701265918486),
        "2B": CLLocationCoordinate2DMake(44.3587935594826, -79.7036924585700),
        "3A": CLLocationCoordinate2DMake(44.3774580323435, -79.6735685346648),
        "3B": CLLocationCoordinate2DMake(44.3789949342968, -79.6709182821214),
        "4A": CLLocationCoordinate2DMake(44.3783744831610, -79.6710442552964),
        "4B": CLLocationCoordinate2DMake(44.3823966019386, -79.6730905358206),
        "5A": CLLocationCoordinate2DMake(44.3907036741725, -79.6899241438279),
        "5B": CLLocationCoordinate2DMake(44.3888411359810, -79.6935332823883),
        "6A": CLLocationCoordinate2DMake(44.3980192281230, -79.7055088093406),
        "6B": CLLocationCoordinate2DMake(44.3976101324705, -79.7047794076113),
        "7A": CLLocationCoordinate2DMake(44.3610299492486, -79.7033370358474),
        "7B": CLLocationCoordinate2DMake(44.3618497989605, -79.7049503804199),
        "8A": CLLocationCoordinate2DMake(44.3750866168115, -79.6862999818308),
        "8B": CLLocationCoordinate2DMake(44.3751863690336, -79.6861355676703),]
    }()
    //Download data
    var session: NSURLSession!
    //Timer
    var getBusTimer: NSTimer!

    
    
//MARK:-
    override func viewDidLoad() {
        super.viewDidLoad()
        busNumTable.registerClass(UITableViewCell.self, forCellReuseIdentifier: "busNumTable")
        busNumTable.hidden = true
        
        //Check Internet Connection
        if (!Reachability.isConnectedToNetwork()) {
            let controller = UIAlertController(title:"Internet Connection Required", message: "Getting current bus location need Internet connection.", preferredStyle:.Alert)
            let action = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
            controller.addAction(action)
            presentViewController(controller, animated: true, completion: nil)
            setRegion(latitude: 44.3893013, longitude: -79.68631744)
        } else {
            initLocation()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

    }
    
//MARK: VIEW LIFE CYCLE
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        let app = UIApplication.sharedApplication()
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "applicationWillEnterForeground:",
            name: UIApplicationWillEnterForegroundNotification,
            object: app)
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
        //remove bus
        map.removeAnnotations(map.annotations)
    }
    
    func applicationWillEnterForeground(notification:NSNotification) {
        if (!Reachability.isConnectedToNetwork()) {
            let controller = UIAlertController(title:"Internet Connection Required", message: "Getting current bus location need Internet connection.", preferredStyle:.Alert)
            let action = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
            controller.addAction(action)
            presentViewController(controller, animated: true, completion: nil)
            setRegion(latitude: 44.3893013, longitude: -79.68631744)
        } else {
            if !inputText.text.isEmpty {
                let region = busRegion[inputText.text]
                setRegion(latitude: region!.latitude, longitude: region!.longitude)
                locationSearch()
            } else {
                initLocation()
            }
        }
    }
    
//MARK: INITIAL CONNECTION
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        let configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration()
        configuration.timeoutIntervalForRequest = 3.0
        session = NSURLSession(configuration: configuration, delegate: nil, delegateQueue: NSOperationQueue.mainQueue())
    }
    
//MARK: INITIAL LOCATION
    //Initial Location
    func initLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10.0
        setRegion(latitude: 44.3893013, longitude: -79.68631744)
        map.delegate = self
        map.showsUserLocation = true
    }
    //Start Locate User
    func locationManager(manager: CLLocationManager!,
        didChangeAuthorizationStatus status: CLAuthorizationStatus) {
            switch status {
            case .Authorized, .AuthorizedWhenInUse:
                locationManager.delegate = self
                locationManager.startUpdatingLocation()
            default:
                locationManager.stopUpdatingLocation()
                locationManager.delegate = nil
                map.showsUserLocation = false
            }
    }
    //Location Error
    func locationManager(manager: CLLocationManager!,
        didFailWithError error: NSError!) {
            let errorMessage = error.code == CLError.Denied.rawValue ? "Access Denied"
                : "Cannot Get Location Information"
            let alertController = UIAlertController(title: "Location Manager Error",
                message: errorMessage, preferredStyle: .Alert)
            let okAction = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
            alertController.addAction(okAction)
            presentViewController(alertController, animated: true, completion: nil)
    }
    //Set Map Region
    func setRegion(#latitude: Double, longitude: Double) {
        let region = MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2DMake(latitude, longitude), 6000, 6000)
        map.setRegion(region, animated: true)
    }
    
//MARK: INPUT
    //Wrap keyboard
    override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        self.view.endEditing(true)
        busNumTable.hidden = true
    }
    //Begin inputting
    @IBAction func beginInput(sender: UITextField) {
        getBusNum()
        busNumTable.reloadData()
        busNumTable.hidden = false
    }
    //Inputing
    @IBAction func inputing(sender: UITextField) {
        if !sender.text.isEmpty {
            getBusNum()
            busNumTable.reloadData()
            busNumTable.hidden = false
        } else {
            map.removeOverlays(map.overlays)
            map.removeAnnotations(map.annotations)
        }
    }
    //Get bus number
    func getBusNum() {
        if (inputText.text != " ") {
            busNum = sorted([String](busUrlWeekday.keys))
        } else {
            busNum = [String](busUrlWeekday.keys).filter{ $0.rangeOfString(self.inputText.text) != nil }
        }
    }
    //Get bus number from database
    func routeSearch(bus: String) {
        //clear location data
        stationLocation.removeAll()
        //open database
        let filePath = NSBundle.mainBundle().pathForResource("app", ofType: "sqlite3")
        var database:COpaquePointer = nil
        var result = sqlite3_open(filePath!, &database)
        if result != SQLITE_OK {
            sqlite3_close(database)
            return
        }
        //query data
        let busNumber = bus
        let query = "SELECT latitude, longitude from station where bus = '\(busNumber)' order by direction asc"
        var statement:COpaquePointer = nil
        if sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let latitude = sqlite3_column_double(statement, 0);
                let longitude = sqlite3_column_double(statement, 1);
                //append value to final result collection every loop
                stationLocation.append(CLLocationCoordinate2DMake(latitude, longitude))
            }
            sqlite3_finalize(statement)
        }
        sqlite3_close(database)
    }
    
    
//MARK: BUS LOCATION
    //Get bus url parameter
    func getBusUrl() -> ([String: String]) {
        let today = NSDate()
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components(.WeekdayCalendarUnit, fromDate: today)
        var weekDay = components.weekday
        switch weekDay {
        case 1:
            return busUrlSun
        case 7:
            return busUrlSat
        default:
            return busUrlWeekday
        }
    }
    
    //Get data from server
    func getCurrentLocation() {
        if (!inputText.text.isEmpty) {
            let busUrl = getBusUrl()
            let urlStr = "http://barrie.mapstrat.com/nextvehicle/BusLocator.axd?&ShapeIDs=\(busUrl[inputText.text]!)"
            let url = NSURL(string: urlStr)
            let task = session.dataTaskWithURL(url!, completionHandler: {
                (data: NSData!, response: NSURLResponse!, error: NSError!) in
                let str = NSString(data: data, encoding: NSUTF8StringEncoding)!
                if str.isEqualToString("PlotBusLocations([]);") {
                    self.map.removeAnnotations(self.map.annotations)
                    let controller = UIAlertController(title:"SORRY", message: "Cannot get bus location information now.", preferredStyle:.Alert)
                    let action = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
                    controller.addAction(action)
                    self.presentViewController(controller, animated: true, completion: nil)
                    self.getBusTimer.invalidate()

                } else {
                    let busLocation = self.switchString(str)
                    self.map.removeAnnotations(self.map.annotations)
                    self.drawBus(busLocation)
                }
            })
            task.resume()
        }
    }
    
    //Change location string to GPS coordinate
    func switchString(locationStr: String) -> [CLLocationCoordinate2D] {
        let sep = NSCharacterSet(charactersInString: ",")
        let stationArr = locationStr.componentsSeparatedByCharactersInSet(sep)
        var latitudeStrArr = [String]()
        var longitudeStrArr = [String]()
        switch stationArr.count {
        case 9:
            latitudeStrArr += [stationArr[1]]
            longitudeStrArr += [stationArr[2]]
        case 18:
            latitudeStrArr += [stationArr[1], stationArr[10]]
            longitudeStrArr += [stationArr[2], stationArr[11]]
        case 27:
            latitudeStrArr += [stationArr[1], stationArr[10], stationArr[19]]
            longitudeStrArr += [stationArr[2], stationArr[11], stationArr[20]]
        case 36:
            latitudeStrArr += [stationArr[1], stationArr[10], stationArr[19], stationArr[28]]
            longitudeStrArr += [stationArr[2], stationArr[11], stationArr[20], stationArr[29]]
        default:
            return [CLLocationCoordinate2D]()
        }
        let latitudeArr: [Double] = latitudeStrArr.map{($0 as NSString).doubleValue}
        let longitudeArr: [Double] = longitudeStrArr.map{($0 as NSString).doubleValue}
        
        var locationArr = [CLLocationCoordinate2D]()
        for i in 1...latitudeArr.count {
            locationArr.append(CLLocationCoordinate2DMake(latitudeArr[i-1], longitudeArr[i-1]))
        }
        return locationArr
    }
    //Repeat get data from server every 5 seconds
    func locationSearch() {
        getBusTimer = NSTimer.scheduledTimerWithTimeInterval(5, target: self, selector:
            Selector("getCurrentLocation"), userInfo: nil, repeats: true)
    }
    

//MARK: MAP ANIMATION
    //Custom animation line
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if (overlay is MKPolyline) {
            var polylineRenderer = MKPolylineRenderer(overlay: overlay)
            polylineRenderer.strokeColor = UIColor.blueColor()
            polylineRenderer.lineWidth = 2
            polylineRenderer.alpha = 0.5
            return polylineRenderer
        }
        return nil
    }
    //Draw bus route and re-set map center
    func drawRoute() {
        map.removeOverlays(map.overlays)
        let region = busRegion[inputText.text]
        setRegion(latitude: region!.latitude, longitude: region!.longitude)
        
        var directionsRequest = MKDirectionsRequest()
        for i in 1 ... stationLocation.count {
            var start, end: MKPlacemark
            if i < stationLocation.count {
                start = MKPlacemark(coordinate: stationLocation[i-1], addressDictionary: nil)
                end = MKPlacemark(coordinate: stationLocation[i], addressDictionary: nil)
            } else {
                start = MKPlacemark(coordinate: stationLocation[i-2], addressDictionary: nil)
                end = MKPlacemark(coordinate: stationLocation[i-1], addressDictionary: nil)
            }
            directionsRequest.setSource(MKMapItem(placemark: start))
            directionsRequest.setDestination(MKMapItem(placemark: end))
            directionsRequest.transportType = MKDirectionsTransportType.Automobile
            directionsRequest.requestsAlternateRoutes = true
            var directions = MKDirections(request: directionsRequest)
            directions.calculateDirectionsWithCompletionHandler { (response:MKDirectionsResponse!, error: NSError!) -> Void in
                if error == nil {
                    self.myRoute = response.routes[0] as? MKRoute
                    self.map.addOverlay(self.myRoute?.polyline)
                }
            }
        }
    }
    //Custom animation point
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        if (annotation is CustomPointAnnotation) {
            var anView = mapView.dequeueReusableAnnotationViewWithIdentifier("bus")
            if anView == nil {
                anView = MKAnnotationView(annotation: annotation, reuseIdentifier: "bus")
                anView.canShowCallout = true
                
            }
            else {
                anView.annotation = annotation
            }
            let point = annotation as CustomPointAnnotation
            anView.image = UIImage(named:point.imageName)
            return anView
        }
        return nil
    }
    //Draw bus
    func drawBus(locationArr: [CLLocationCoordinate2D]) {
        for bus in locationArr {
            let busLocation = CustomPointAnnotation()
            busLocation.imageName = "bus"
            busLocation.title = inputText.text
            busLocation.coordinate = bus
            map.addAnnotation(busLocation)
        }
    }
    
}

extension MapViewController: UITableViewDataSource {
    //return number of rows
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return busNum.count
    }
    //return countent of rows
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) ->
        UITableViewCell {
        let cell = UITableViewCell(style:UITableViewCellStyle.Default,reuseIdentifier: "busNumTable")
        cell.textLabel?.text = busNum[indexPath.row]
        cell.imageView?.image = UIImage(named: "bus")
        return cell
    }
}

extension MapViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let busNumber = busNum[indexPath.row]
        inputText.resignFirstResponder()
        inputText.text = busNumber
        busNumTable.hidden = true
        //get bus route
        routeSearch(busNumber)
        drawRoute()
        //get bus location
        if let oldTimer = getBusTimer {
            oldTimer.invalidate()
        }
        locationSearch()
    }
}
