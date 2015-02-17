//
//  ScheduleViewController.swift
//  BarrieTransit
//
//  Created by Robin on 2015-01-21.
//  Copyright (c) 2015 Huibin Zhao. All rights reserved.
//

import UIKit

class ScheduleViewController: UIViewController {
    @IBOutlet weak var inputTextFiled: UITextField!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var testLabel: UILabel!
    @IBOutlet weak var stopTableView: UITableView!
    
    @IBOutlet weak var busTableView: UITableView!
    var scheduleResult = [String: [Int]]()             //schedule result
    var minScheduleResult = [String: Int]()            //first data of schedule result
    var stopResult = [String]()                        //stopNumber result
    
//MARK:-
    override func viewDidLoad() {
        super.viewDidLoad()
        //initial declear two table
        stopTableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "stopTable")
        busTableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "busTable")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
//MARK: INPUT
    //when start inputing, get the stop number, load the data into a table view, and show it up
    @IBAction func beginInput(sender: UITextField) {
        getStopResult(inputTextFiled.text.toInt())
        stopTableView.reloadData()
        busTableView.hidden = true
        stopTableView.hidden = false
    }
    
    //inputting
    @IBAction func inputing(sender: UITextField) {
        getStopResult(inputTextFiled.text.toInt())
        stopTableView.reloadData()
        stopTableView.hidden = false
        busTableView.hidden = true
    }
    
    //wrap keyboard
    override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        self.view.endEditing(true)
        stopTableView.hidden = true
    }
    //check input number validity
    func checkInput() -> Bool {
        if (!contains(stopResult, inputTextFiled.text)) {
            let controller = UIAlertController(title:"Invalid Number", message: "please input a valid stop number", preferredStyle:.Alert)
            let action = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
            controller.addAction(action)
            presentViewController(controller, animated: true, completion: nil)
            return false
        } else {
            return true
        }
    }
    

//MARK: TIME FUNCTIONS
    //get time variables: weedDay, hour, minute
    func getTime() -> (Int, Int, Int) {
        let today = NSDate()
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components(.CalendarUnitHour | .CalendarUnitMinute | .WeekdayCalendarUnit, fromDate: today)
        let hour = components.hour
        let minute = components.minute
        var weekDay = components.weekday
        switch weekDay {
        case 1:
            weekDay = 3
        case 7:
            weekDay = 2
        default:
            weekDay = 1
        }
        return (hour, minute, weekDay)
    }
    
//MARK: DATABASE QUERY FUNCTION
    //query stop number
    func getStopResult(number: Int?) {
        //open database
        let filePath = NSBundle.mainBundle().pathForResource("app", ofType: "sqlite3")
        var database:COpaquePointer = nil
        var result = sqlite3_open(filePath!, &database)
        if result != SQLITE_OK {
            sqlite3_close(database)
            return
        }
        //query data
        stopResult = []
        var query = ""
        if let queryNumber = number {
            query = "SELECT distinct stop from schedule where stop like '\(queryNumber)%' order by stop"
        } else {
            query = "SELECT distinct stop from schedule order by stop"
        }
        var statement:COpaquePointer = nil
        if sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let stop = Int(sqlite3_column_int(statement, 0))
                //append value to final result collection every loop
                stopResult.append(String(stop))
            }
            sqlite3_finalize(statement)
        }
        sqlite3_close(database)
    }

    //query schedule
    @IBAction func search(sender: UIButton) {
        //firstly check input
        if checkInput() {
            //initial schedule array
            scheduleResult.removeAll(keepCapacity: true)
            //open database
            let filePath = NSBundle.mainBundle().pathForResource("app", ofType: "sqlite3")
            var database:COpaquePointer = nil
            var result = sqlite3_open(filePath!, &database)
            if result != SQLITE_OK {
                sqlite3_close(database)
                return
            }
            //query data
            let stopNumber = inputTextFiled.text.toInt()!
            var (currentHour, currentMinute, weekDay) = getTime()
            let query = "SELECT bus, hour, minute from schedule where stop = \(stopNumber) and weekDay >= \(weekDay) and hour >= \(currentHour) order by bus, hour, minute"
            var statement:COpaquePointer = nil
            if sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    let stop = sqlite3_column_text(statement, 0)
                    let stopNumber = String.fromCString(UnsafePointer<CChar>(stop))
                    let hour = Int(sqlite3_column_int(statement, 1))
                    let minute = Int(sqlite3_column_int(statement, 2))
                    let duration = (hour - currentHour) * 60 + minute - currentMinute
                    //append value to final result collection every loop
                    if scheduleResult[stopNumber!] == nil {
                        scheduleResult[stopNumber!] = []
                    }
                    if duration >= 0 {
                        scheduleResult[stopNumber!]?.append(duration)
                    }
                }
                sqlite3_finalize(statement)
            }
            getFirstTime()
            busTableView.reloadData()
            //Notice when no bus for today
            if scheduleResult.isEmpty {
                let controller = UIAlertController(title:"Bad Luck", message: "this is no bus for today", preferredStyle:.Alert)
                let action = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
                controller.addAction(action)
                presentViewController(controller, animated: true, completion: nil)
            }
            sqlite3_close(database)
            stopTableView.hidden = true
            busTableView.hidden = false
            
            self.view.endEditing(true)
        } else {
            inputTextFiled.becomeFirstResponder()
        }
    }

    
    func getFirstTime() {
        minScheduleResult.removeAll(keepCapacity: true)
        for (key, value) in scheduleResult {
            minScheduleResult[key] = value[0]
        }
    }
    
    
//MARK: Navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {

        let indexPath = busTableView.indexPathForSelectedRow()!
        let detailTable = segue.destinationViewController as ScheduleDetailViewController
        
        if segue.identifier == "detail" {
            let bus = [String](scheduleResult.keys)[indexPath.row]
            let schedules = scheduleResult[bus]
            detailTable.navigationItem.title = bus
            detailTable.bus = bus
            detailTable.schedule = schedules!
        }
    }
    
}


extension ScheduleViewController: UITableViewDataSource {
    //return number of rows
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.stopTableView {
            return stopResult.count
        } else {
            return [String](minScheduleResult.keys).count
        }
        
    }
    
    //return countent of rows
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) ->
        UITableViewCell {
            
            if tableView == self.stopTableView {
                let cell = UITableViewCell(style:UITableViewCellStyle.Default,reuseIdentifier: "stopTable")
                cell.textLabel?.text = sorted(stopResult)[indexPath.row]
                cell.imageView?.image = UIImage(named: "station")
                return cell
            } else {
                let cell = UITableViewCell(style:UITableViewCellStyle.Default,reuseIdentifier: "busTable")
                let key = [String](minScheduleResult.keys)[indexPath.row]
                let values = minScheduleResult[key]!
                cell.textLabel?.text = key + ": \t" + String(values) + " min"
                cell.imageView?.image = UIImage(named: "bus")
                cell.accessoryType = UITableViewCellAccessoryType.DisclosureIndicator
                return cell
            }
    }
    
}


extension ScheduleViewController: UITableViewDelegate {
    //select one of stop list and pass it into input textfield
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if tableView == self.stopTableView {
            let stopNumber = stopResult[indexPath.row]
            inputTextFiled.text = stopNumber
            search(searchButton)
            stopTableView.hidden = true
            busTableView.hidden = false
        } else {
            self.performSegueWithIdentifier("detail", sender:tableView)
        }
    }
}
