//
//  ScheduleDetailViewController.swift
//  BarrieTransit
//
//  Created by Robin on 2015-01-26.
//  Copyright (c) 2015 Huibin Zhao. All rights reserved.
//

import UIKit

class ScheduleDetailViewController: UITableViewController {

    var bus: String = ""
    var schedule = [Int]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }


    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return schedule.count
    }


    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("detailTable", forIndexPath: indexPath) as UITableViewCell

        let value = schedule[indexPath.row]
        cell.textLabel?.text = bus + ": \t" + String(value) + " min"
        cell.imageView?.image = UIImage(named: "bus")
        return cell
    }

}
