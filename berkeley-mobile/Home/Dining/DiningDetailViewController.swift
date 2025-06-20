//
//  DiningDetailViewController.swift
//  bm-persona
//
//  Created by Shawn Huang on 4/4/20.
//  Copyright © 2020 RJ Pimentel. All rights reserved.
//

import CoreLocation
import Firebase
import UIKit
import SwiftUI

// MARK: - DiningDetailView

struct DiningDetailView: UIViewControllerRepresentable {
    typealias UIViewControllerType = DiningDetailViewController
    
    private let diningHall: BMDiningLocation
    
    init(diningHall: BMDiningLocation) {
        self.diningHall = diningHall
    }
    
    func makeUIViewController(context: Context) -> DiningDetailViewController {
        let diningDetailVC = DiningDetailViewController()
        diningDetailVC.diningHall = diningHall
        return diningDetailVC
    }
    
    func updateUIViewController(_ uiViewController: DiningDetailViewController, context: Context) {}
}


// MARK: - DiningDetailViewController

fileprivate let kCardPadding: UIEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
fileprivate let kViewMargin: CGFloat = 16

class DiningDetailViewController: UIViewController {
    static let mealTimesChronological = ["breakfast": 0, "brunch": 1, "lunch": 2, "dinner": 3, "late night": 4, "other": 5]

    var diningHall: BMDiningLocation!
    var overviewCard: OverviewCardView!

    override func viewDidLoad() {
        super.viewDidLoad()

        setUpOverviewCard()
        view.layoutSubviews()
    }
}

extension DiningDetailViewController {
    func setUpOverviewCard() {
        overviewCard = OverviewCardView(item: diningHall)
        view.addSubview(overviewCard)
        overviewCard.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: kViewMargin).isActive = true
        overviewCard.leftAnchor.constraint(equalTo: view.layoutMarginsGuide.leftAnchor).isActive = true
        overviewCard.rightAnchor.constraint(equalTo: view.layoutMarginsGuide.rightAnchor).isActive = true
        overviewCard.heightAnchor.constraint(equalToConstant: 200).isActive = true
        view.layoutSubviews()
    }

    func setUpMenuControl() {
        let meals = diningHall.meals
        guard meals.count > 0 else { return }

        /* If an open/close time interval exists for all meal names today,
           sort meal times chronologically using the fetched time intervals,
           otherwise, sort meal times chronologically using the `mealTimesChronological` dictionary,
           which currently supports Breakfast, Brunch, Lunch, Dinner, Late Night. */
        let now = Date()
        var currentMealIndex = 0
        let mealNames: [String]
        if let hours = diningHall.weeklyHours?.hoursForWeekday(DayOfWeek.weekday(now)),
           let mealHours = parseMealTimes(meals: meals, hours: hours) {
            mealNames = meals.keys.sorted(by: { (meal1, meal2) -> Bool in
                guard let interval1 = mealHours[meal1],
                      let interval2 = mealHours[meal2] else {
                    return true
                }
                return interval1 < interval2
            })
            // Select the meal happening now, or the next one
            currentMealIndex = mealNames.firstIndex(where: { meal in
                guard let interval = mealHours[meal] else { return false }
                return interval.contains(now) || interval.start > now
            }) ?? 0
        } else {
            mealNames = Array(meals.keys).sorted(by: { (meal1, meal2) -> Bool in
                let m1Priority = DiningDetailViewController.mealTimesChronological[meal1.lowercased()] ??
                    DiningDetailViewController.mealTimesChronological["other"]!
                let m2Priority = DiningDetailViewController.mealTimesChronological[meal2.lowercased()] ??
                    DiningDetailViewController.mealTimesChronological["other"]!
                return m1Priority < m2Priority
            })
        }

        let filter = FilterView(frame: .zero)
        filter.contentInset = UIEdgeInsets(top: 0, left: kViewMargin, bottom: 0, right: kViewMargin)
        filter.heightAnchor.constraint(equalToConstant: FilterViewCell.kCellSize.height).isActive = true
        let padding = UIView()
        padding.heightAnchor.constraint(equalToConstant: kViewMargin).isActive = true
    }

    /**
     Parse the notes in today's `hours` to create a mapping between meal names and open hours.
     Returns a dictionary containing the parsed results, or `nil` if open hours for any meal are not found.
     */
    private func parseMealTimes(meals: MealMap, hours: DailyHoursType) -> [MealType: DateInterval]? {
        // Parse `hours` for mapping between note and date interval
        var noteHours = [String: DateInterval]()
        hours.forEach { hoursInterval in
            guard let note = hoursInterval.note else { return }
            noteHours[note] = hoursInterval.dateInterval
        }

        // Lookup meal keys in `noteHours` to get date intervals for each meal
        var mealHours = [MealType: DateInterval]()
        for meal in meals.keys {
            if let interval = noteHours[meal] {
                mealHours[meal] = interval
            } else {
                return nil
            }
        }
        return mealHours
    }
}


// MARK: - Analytics

extension DiningDetailViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Analytics.logEvent("opened_food", parameters: ["dining_location" : diningHall.name])
    }
}
