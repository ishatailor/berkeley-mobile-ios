//
//  AcademicCalendarViewController.swift
//  berkeley-mobile
//
//  Created by Kevin Hu on 9/22/20.
//  Copyright © 2020 ASUC OCTO. All rights reserved.
//

import Firebase
import UIKit
import SwiftUI

struct AcademicCalendarView: UIViewControllerRepresentable {
    typealias UIViewControllerType = AcademicCalendarViewController
    
    func makeUIViewController(context: Context) -> AcademicCalendarViewController {
        AcademicCalendarViewController()
    }
    
    func updateUIViewController(_ uiViewController: AcademicCalendarViewController, context: Context) {}
}


// MARK: - AcademicCalendarViewController

fileprivate let kCardPadding: UIEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
fileprivate let kViewMargin: CGFloat = 6

/// Displays the 'Academic' events in the Calendar tab.
class AcademicCalendarViewController: UIViewController {
    
    private var scrollingStackView: ScrollingStackView!
    private var calendarTablePair: CalendarTablePairView!
    
    private let eventScrapper = EventScrapper()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Note: The top inset value will be also used as a vertical margin for `scrollingStackView`.
        self.view.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 16, right: 16)
        
        setupScrollView()
        setUpCalendar()
        scrapeAcademicEvents()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Analytics.logEvent("opened_academic_calendar", parameters: nil)
    }

    private func scrapeAcademicEvents() {
        calendarTablePair.isLoading = true
        
        eventScrapper.delegate = self
        
        let academicCalendarURLString = EventScrapper.Constants.academicCalendarURLString
        let rescapeData = eventScrapper.shouldRescrape(for: academicCalendarURLString, lastRefreshDateKey: UserDefaultsKeys.academicEventsLastSavedDate.rawValue)
        
        if rescapeData.shouldRescape {
            eventScrapper.scrape(at: academicCalendarURLString)
        } else {
            DispatchQueue.main.async {
                self.calendarTablePair.isLoading = false
                self.calendarTablePair.setCalendarEntries(entries: rescapeData.savedEvents)
            }
        }
    }
    
    private func setupScrollView() {
        scrollingStackView = ScrollingStackView()
        scrollingStackView.setLayoutMargins(view.layoutMargins)
        scrollingStackView.scrollView.showsVerticalScrollIndicator = false
        scrollingStackView.stackView.spacing = kViewMargin
        view.addSubview(scrollingStackView)
        scrollingStackView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor).isActive = true
        scrollingStackView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        scrollingStackView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        scrollingStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
    
    private func setUpCalendar() {
        let card = CardView()
        card.layoutMargins = kCardPadding
        scrollingStackView.stackView.addArrangedSubview(card)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.bottomAnchor.constraint(equalTo: self.view.layoutMarginsGuide.bottomAnchor).isActive = true
        
        calendarTablePair = CalendarTablePairView(parentVC: self)
        card.addSubview(calendarTablePair)
        calendarTablePair.topAnchor.constraint(equalTo: card.layoutMarginsGuide.topAnchor).isActive = true
        calendarTablePair.bottomAnchor.constraint(equalTo: card.layoutMarginsGuide.bottomAnchor).isActive = true
        calendarTablePair.leftAnchor.constraint(equalTo: card.layoutMarginsGuide.leftAnchor).isActive = true
        calendarTablePair.rightAnchor.constraint(equalTo: card.layoutMarginsGuide.rightAnchor).isActive = true
    }
}


// MARK: - EventScrapperDelegate

extension AcademicCalendarViewController: EventScrapperDelegate {
    
    func eventScrapperDidFinishScrapping(results: [EventCalendarEntry]) {
        calendarTablePair.isLoading = false
        calendarTablePair.setCalendarEntries(entries: results)
    }
    
    func eventScrapperDidError(with errorDescription: String) {
        calendarTablePair.isLoading = false
        presentFailureAlert(title: "Unable To Parse Website", message: errorDescription)
    }

}

