//
//  QuickTableViewController.swift
//  QuickTableViewController
//
//  Created by Ben on 25/08/2015.
//  Copyright (c) 2015 bcylin.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import UIKit

/// A table view controller that shows `tableContents` as formatted sections and rows.
class QuickTableViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

  /// A Boolean value indicating if the controller clears the selection when the collection view appears.
  open var clearsSelectionOnViewWillAppear = true

  /// Returns the table view managed by the controller object.
  open var tableView: UITableView = UITableView(frame: .zero, style: .grouped)

  /// The layout of sections and rows to display in the table view.
  open var tableContents: [Section] = [] {
    didSet {
      tableView.reloadData()
    }
  }

  // MARK: - Initialization

  /// Initializes a table view controller to manage a table view of a given style.
  ///
  /// - Parameter style: A constant that specifies the style of table view that the controller object is to manage.
  public init(style: UITableView.Style) {
    super.init(nibName: nil, bundle: nil)
    tableView = UITableView(frame: .zero, style: style)
  }

  /// Returns a newly initialized view controller with the nib file in the specified bundle.
  ///
  /// - Parameters:
  ///   - nibNameOrNil: The name of the nib file to associate with the view controller.
  ///   - nibBundleOrNil: The bundle in which to search for the nib file.
  public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
  }

  /// Returns an object initialized from data in a given unarchiver.
  ///
  /// - Parameter coder: An unarchiver object.
  public required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  deinit {
    tableView.dataSource = nil
    tableView.delegate = nil
  }

  // MARK: - UIViewController

  open override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(tableView)
    tableView.snp.makeConstraints { make in
        make.top.bottom.equalToSuperview()
        make.leading.trailing.equalToSuperview().inset(Constants.Size.ContentSpaceMin)
    }
    tableView.backgroundColor = Constants.Color.BackgroundPrimary
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 44
    tableView.dataSource = self
    tableView.delegate = self
    tableView.showsVerticalScrollIndicator = false
    tableView.showsHorizontalScrollIndicator = false
    tableView.contentInset = UIEdgeInsets(top: Constants.Size.ItemHeightMid, left: 0, bottom: Constants.Size.ContentInsetBottom, right: 0)
    #if os(tvOS)
    tableView.remembersLastFocusedIndexPath = true
    #endif
  }

  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if let indexPath = tableView.indexPathForSelectedRow, clearsSelectionOnViewWillAppear {
      tableView.deselectRow(at: indexPath, animated: true)
    }
  }

  // MARK: - UITableViewDataSource

  open func numberOfSections(in tableView: UITableView) -> Int {
    return tableContents.count
  }

  open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return tableContents[section].rows.count
  }
    
  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
      let title = tableContents[section].title
      guard let title else { return nil }
      let label = UILabel()
      label.textColor = Constants.Color.LabelPrimary
      label.text = title
      if tableContents[section].rows.count == 0 {
          label.font = Constants.Font.title()
      } else {
          label.font = Constants.Font.body(size: .l, weight: .semibold)
      }
      return label
  }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if tableContents[section].title == nil {
            return 0
        }
        return Constants.Size.ItemHeightMid
    }

  open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let row = tableContents[indexPath.section].rows[indexPath.row]
    let cell =
      tableView.dequeueReusableCell(withIdentifier: row.cellReuseIdentifier) ??
      row.cellType.init(style: row.cellStyle, reuseIdentifier: row.cellReuseIdentifier)

    cell.defaultSetUp(with: row)
    (cell as? Configurable)?.configure(with: row)
    #if os(iOS)
      (cell as? SwitchCell)?.delegate = self
    #endif
    row.customize?(cell, row)
    cell.backgroundColor = Constants.Color.BackgroundSecondary

    return cell
  }
    
  func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
      let title = tableContents[section].footer
      guard let title else { return nil }
      let label = UILabel()
      label.numberOfLines = 0
      label.text = "\n" + title + "\n\n"
      label.textColor = Constants.Color.LabelSecondary
      label.font = Constants.Font.caption()
      return label
  }

  // MARK: - UITableViewDelegate

  open func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
    return tableContents[indexPath.section].rows[indexPath.row].isSelectable
  }

  open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let section = tableContents[indexPath.section]
    let row = section.rows[indexPath.row]

    switch (section, row) {
    case let (radio as RadioSection, option as OptionRowCompatible):
      let changes: [IndexPath] = radio.toggle(option).map {
        IndexPath(row: $0, section: indexPath.section)
      }
      if changes.isEmpty {
        tableView.deselectRow(at: indexPath, animated: false)
      } else {
        tableView.reloadRows(at: changes, with: .automatic)
      }

    case let (_, option as OptionRowCompatible):
      // Allow OptionRow to be used without RadioSection.
      section.rows.forEach({
          if let othreOption = $0 as? OptionRowCompatible {
              othreOption.isSelected = false
          }
      })
      option.isSelected = !option.isSelected
        
      tableView.reloadData()

    #if os(tvOS)
    case let (_, row as SwitchRowCompatible):
      // SwitchRow on tvOS behaves like OptionRow.
      row.switchValue = !row.switchValue
      tableView.reloadData()
    #endif

    case (_, is TapActionRowCompatible):
      tableView.deselectRow(at: indexPath, animated: true)
      // Avoid some unwanted animation when the action also involves table view reload.
      DispatchQueue.main.async {
        row.action?(row)
      }

    case let (_, row) where row.isSelectable:
      DispatchQueue.main.async {
        row.action?(row)
        tableView.deselectRow(at: indexPath, animated: true)
      }

    default:
      break
    }
  }

  #if os(iOS)
  public func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
    switch tableContents[indexPath.section].rows[indexPath.row] {
    case let row as NavigationRowCompatible:
      DispatchQueue.main.async {
        row.accessoryButtonAction?(row)
      }
    default:
      break
    }
  }
  #endif

  #if os(tvOS)
  private var currentFocusedIndexPath: IndexPath?

  open override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
    currentFocusedIndexPath = (context.nextFocusedView as? UITableViewCell).flatMap(tableView.indexPath(for:))
  }

  public func indexPathForPreferredFocusedView(in tableView: UITableView) -> IndexPath? {
    return currentFocusedIndexPath
  }
  #endif

}

// MARK: - SwitchCellDelegate

#if os(iOS)
extension QuickTableViewController: SwitchCellDelegate {

  @objc
  open func switchCell(_ cell: SwitchCell, didToggleSwitch isOn: Bool) {
    guard
      let indexPath = tableView.indexPath(for: cell),
      let row = tableContents[indexPath.section].rows[indexPath.row] as? SwitchRowCompatible
    else {
      return
    }
    row.switchValue = isOn
  }

}
#endif
