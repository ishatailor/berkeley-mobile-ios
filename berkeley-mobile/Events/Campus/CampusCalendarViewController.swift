//
//  CampusCalendarViewController.swift
//  berkeley-mobile
//
//  Created by Kevin Hu on 9/22/20.
//  Copyright © 2020 ASUC OCTO. All rights reserved.
//

import Firebase
import UIKit
import SwiftUI

struct CampusCalendarView: UIViewControllerRepresentable {
    typealias UIViewControllerType = CampusCalendarViewController
    
    func makeUIViewController(context: Context) -> CampusCalendarViewController {
        CampusCalendarViewController()
    }
    
    func updateUIViewController(_ uiViewController: CampusCalendarViewController, context: Context) {}
}


// MARK: - CampusCalendarViewController

fileprivate let kCardPadding: UIEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
fileprivate let kViewMargin: CGFloat = 16

/// Displays the campus-wide and org. events in the Calendar tab.
class CampusCalendarViewController: UIViewController {
    
    private var scrollingStackView: ScrollingStackView!

    private var upcomingMissingView: MissingDataView!
    private var eventsCollection: CardCollectionView!

    private var calendarMissingView: MissingDataView!
    private var calendarTable: UITableView!

    private var calendarEntries: [EventCalendarEntry] = []
    
    private let eventScrapper = EventScrapper()
    private var isLoading = false
    private var numOfRescrapes = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        // Note: The top inset value will be also used as a vertical margin for `scrollingStackView`.
        self.view.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 16, right: 16)
        
        setupScrollView()
        setupCalendarList()
        scrapeCampuswideData()
    }
    
    private func scrapeCampuswideData() {
        isLoading = true
        calendarTable.reloadData()
        
        eventScrapper.delegate = self
        
        let campusWideCalendarURLString = EventScrapper.Constants.campuswideCalendarURLString
        let rescapeData = eventScrapper.shouldRescrape(for: campusWideCalendarURLString, lastRefreshDateKey: UserDefaultsKeys.campuswideEventsLastSavedDate.rawValue)
        
        if rescapeData.shouldRescape {
            eventScrapper.scrape(at: campusWideCalendarURLString)
        } else {
            calendarEntries = rescapeData.savedEvents
            isLoading = false
            reloadCalendarTableView()
        }
    }
    
    private func reloadCalendarTableView() {
        if calendarEntries.isEmpty {
            hideCalendarTable()
        } else {
            showCalendarTable()
            calendarTable.reloadData()
        }
    }
    
    private func showCalendarTable() {
        calendarMissingView.isHidden = true
        calendarTable.isHidden = false
    }
    
    private func hideCalendarTable() {
        calendarMissingView.isHidden = false
        calendarTable.isHidden = true
    }
}

// MARK: - EventScrapperDelegate
extension CampusCalendarViewController: EventScrapperDelegate {
    
    func eventScrapperDidFinishScrapping(results: [EventCalendarEntry]) {
        calendarEntries = results
        isLoading = false
        reloadCalendarTableView()
    }
    
    func eventScrapperDidError(with errorDescription: String) {
        presentFailureAlert(title: "Unable To Parse Website", message: errorDescription)
        reloadCalendarTableView()
    }
    
}

// MARK: - Calendar Table Delegates

extension CampusCalendarViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isLoading ? 5 : calendarEntries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isLoading {
            let cell = tableView.dequeueReusableCell(withIdentifier: SkeletonLoadingCell.kCellIdentifier, for: indexPath)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: CampusEventTableViewCell.kCellIdentifier, for: indexPath)
            
            guard let entry = calendarEntries[safe: indexPath.row] else {
                return cell
            }
            
            let cellViewModel = CampusEventRowViewModel()
            cellViewModel.configure(with: entry)
            
            cell.contentConfiguration = UIHostingConfiguration {
                CampusEventRowView()
                    .environmentObject(cellViewModel)
            }
            
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc = CampusEventDetailViewController()
        if let entry = calendarEntries[safe: indexPath.row] {
            vc.event = entry
            present(vc, animated: true)
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
}

// MARK: - Upcoming Card Delegates

extension CampusCalendarViewController: UICollectionViewDelegate, UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return min(calendarEntries.count, 4)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if isLoading {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SkeletonLoadingCell.kCellIdentifier, for: indexPath)
            return cell
        }
        
        // Load actual data
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CampusEventCollectionViewCell.kCellIdentifier, for: indexPath)
        
        if let card = cell as? CampusEventCollectionViewCell,
            let entry = calendarEntries[safe: indexPath.row] {
            card.updateContents(event: entry)
        }
            
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let vc = CampusEventDetailViewController()
        if let entry = calendarEntries[safe: indexPath.row] {
            vc.event = entry
            present(vc, animated: true)
        }
    }
}

// MARK: - MissingDataViewDelegate

extension CampusCalendarViewController: MissingDataViewDelegate {
    
    func missingDataViewDidReload() {
        showCalendarTable()
        scrapeCampuswideData()
    }

}

// MARK: - View

extension CampusCalendarViewController {

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

    // MARK: Upcoming Card

    private func setupUpcoming() {
        let card = CardView()
        card.layoutMargins = kCardPadding
        scrollingStackView.stackView.addArrangedSubview(card)

        let contentView = UIView()
        contentView.layer.masksToBounds = true
        card.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.setConstraintsToView(top: card, bottom: card, left: card, right: card)

        let headerLabel = UILabel()
        headerLabel.font = BMFont.bold(24)
        headerLabel.text = "Upcoming"
        contentView.addSubview(headerLabel)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.topAnchor.constraint(equalTo: card.layoutMarginsGuide.topAnchor).isActive = true
        headerLabel.leftAnchor.constraint(equalTo: card.layoutMarginsGuide.leftAnchor).isActive = true
        headerLabel.rightAnchor.constraint(equalTo: card.layoutMarginsGuide.rightAnchor).isActive = true

        let collectionView = CardCollectionView(frame: .zero)
        collectionView.register(CampusEventCollectionViewCell.self, forCellWithReuseIdentifier: CampusEventCollectionViewCell.kCellIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.contentInset = UIEdgeInsets(top: 0, left: card.layoutMargins.left, bottom: 0, right: card.layoutMargins.right)
        contentView.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 16).isActive = true
        collectionView.heightAnchor.constraint(equalToConstant: CampusEventCollectionViewCell.kCardSize.height).isActive = true
        collectionView.leftAnchor.constraint(equalTo: card.leftAnchor).isActive = true
        collectionView.rightAnchor.constraint(equalTo: card.rightAnchor).isActive = true
        collectionView.bottomAnchor.constraint(equalTo: card.layoutMarginsGuide.bottomAnchor).isActive = true

        eventsCollection = collectionView
        upcomingMissingView = MissingDataView(parentView: collectionView, text: "No upcoming events")
    }

    // MARK: Calendar Table

    private func setupCalendarList() {
        let card = CardView()
        card.layoutMargins = kCardPadding
        scrollingStackView.stackView.addArrangedSubview(card)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor).isActive = true

        let table = UITableView()
        table.register(CampusEventTableViewCell.self, forCellReuseIdentifier: CampusEventTableViewCell.kCellIdentifier)
        table.register(SkeletonLoadingCell.self, forCellReuseIdentifier: SkeletonLoadingCell.kCellIdentifier)
        table.rowHeight = CampusEventTableViewCell.kCellHeight
        table.backgroundColor = BMColor.cardBackground
        table.delegate = self
        table.dataSource = self
        table.showsVerticalScrollIndicator = false
        table.separatorStyle = .none
        card.addSubview(table)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.topAnchor.constraint(equalTo: card.layoutMarginsGuide.topAnchor).isActive = true
        table.leftAnchor.constraint(equalTo: card.layoutMarginsGuide.leftAnchor).isActive = true
        table.rightAnchor.constraint(equalTo: card.layoutMarginsGuide.rightAnchor).isActive = true
        table.bottomAnchor.constraint(equalTo: card.layoutMarginsGuide.bottomAnchor).isActive = true

        calendarTable = table
        calendarMissingView = MissingDataView(parentView: card, text: "No events found")
        calendarMissingView.showReloadButton(withTitle: "Reload Events")
        calendarMissingView.delegate = self
    }
}

extension CampusCalendarViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Analytics.logEvent("opened_campus_wide_events", parameters: nil)
    }
}
