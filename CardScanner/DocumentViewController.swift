//
//  DocumentViewController.swift
//  CardScanner
//
//  Created by Luke Van In on 2017/02/15.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import UIKit
import MapKit
import CoreData
import Contacts
import MessageUI

private let basicCellIdentifier = "BasicCell"
private let addressCellIdentifier = "AddressCell"
private let imageCellIdentifier = "ImageCell"

extension FragmentType {
    var color: UIColor {
        switch self {
        case .address:
            return Material.Color.blueGrey
            
        case .person:
            return Material.Color.pink
            
        case .organization:
            return Material.Color.lightBlue
            
        case .email:
            return Material.Color.green
            
        case .url:
            return Material.Color.teal
            
        case .phoneNumber:
            return Material.Color.cyan
            
        case .note:
            return Material.Color.lime
            
        default:
            return Material.Color.grey
        }
    }
}

class DocumentViewController: UITableViewController, TextCellDelegate {
    
    class Section {
        let title: String
        let type: FragmentType
        var values: [Fragment]
        
        init(title: String, type: FragmentType, values: [Fragment]) {
            self.title = title
            self.type = type
            self.values = values
        }
        
        @discardableResult func remove(at: Int) -> Fragment {
            let output = values.remove(at: at)
            updateOrdering(from: at)
            return output
        }
        
        func append(_ fragment: Fragment) {
            insert(fragment, at: values.count)
        }
        
        func insert(_ fragment: Fragment, at: Int) {
            fragment.type = type
            fragment.ordinality = Int32(at)
            values.insert(fragment, at: at)
            updateOrdering(from: at)
        }
        
        func updateOrdering() {
            updateOrdering(from: 0)
        }
        
        func updateOrdering(from: Int) {
            for i in from ..< values.count {
                values[i].ordinality = Int32(i)
            }
        }
    }

    var documentIdentifier: String!
    var coreData: CoreDataStack!
    
    private lazy var scanner: ScannerService = {
        let factory = DefaultServiceFactory()
        return ScannerService(
            factory: factory,
            coreData: self.coreData
        )
    }()
    
    private var sections = [Section]()
    private var activeSections = [Int]()
    
    @IBOutlet weak var headerImageContainerView: UIView!
    @IBOutlet weak var headerImageView: UIImageView!
    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var headerImageWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var headerImageHeightConstraint: NSLayoutConstraint!
    
    @IBAction func onScanAction(_ sender: Any) {
        if isEditing {
            isEditing = false
        }
        
        clearDocument() {
            DispatchQueue.main.async {
                self.scanDocument()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableViewAutomaticDimension
        navigationItem.rightBarButtonItem = editButtonItem
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadDocument()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateImageSize()
    }
    
    private func updateImageSize() {
        
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        // Rows
        activeSections.removeAll()
        
        tableView.beginUpdates()
        
        if editing {
            // Edit mode.
            // Insert one additional row for each section.
            var indexPaths = [IndexPath]()
            var sectionIndices = IndexSet()
            for i in 0 ..< sections.count {
                let section = sections[i]
                activeSections.append(i)
                
                let count = section.values.count
                
                if count == 0 {
                    sectionIndices.insert(i)
                }
                else {
                    
                }
                
                let indexPath = IndexPath(row: count, section: i)
                indexPaths.append(indexPath)
            }
            tableView.insertSections(sectionIndices, with: .automatic)
            tableView.insertRows(at: indexPaths, with: .automatic)
        }
        else {
            // Non-edit mode.
            // Remove additional row for each section.
            var indexPaths = [IndexPath]()
            var sectionIndices = IndexSet()
            for i in 0 ..< sections.count {
                let section = sections[i]
                let count = section.values.count
                
                if count == 0 {
                    sectionIndices.insert(i)
                }
                else {
                    activeSections.append(i)
                }
                
                let indexPath = IndexPath(row: count, section: i)
                indexPaths.append(indexPath)
            }
            tableView.deleteRows(at: indexPaths, with: .automatic)
            tableView.deleteSections(sectionIndices, with: .automatic)
        }
        
        tableView.endUpdates()
        
        for cell in tableView.visibleCells {
            if let cell = cell as? BasicFragmentCell {
                cell.editingEnabled = editing
            }
        }
    }
    
    // MARK: Document
    
    private func clearDocument(completion: @escaping () -> Void) {
        sections.removeAll()
        activeSections.removeAll()
        tableView.reloadData()
        
        coreData.performBackgroundChanges { [documentIdentifier] (context) in
            
            let document = try context.documents(withIdentifier: documentIdentifier!).first
            
            if let fragments = document?.fragments?.allObjects as? [Fragment] {
                for fragment in fragments {
                    context.delete(fragment)
                }
            }
            
            do {
                try context.save()
            }
            catch {
                print("Cannot remove fragments from document: \(error)")
            }
            
            completion()
        }
    }
    
    private func loadDocument() {
        do {
            var sections = [Section]()
            let document = try coreData.mainContext.documents(withIdentifier: documentIdentifier).first
            
            if let imageData = document?.imageData {
                headerImageView.image = UIImage(data: imageData as Data)
                updateImageSize()
            }

            if let fragments = document?.fragments?.allObjects as? [Fragment] {
                
                func filterFragments(_ type: FragmentType) -> [Fragment] {
                    return fragments
                        .filter() { $0.type == type }
                        .sorted() { $0.ordinality < $1.ordinality }
                }
                
                func makeSection(title: String, type: FragmentType) -> Section {
                    return Section(
                        title: title,
                        type: type,
                        values: filterFragments(type)
                    )
                }
                
                sections.append(makeSection(title: "Person", type: .person))
                sections.append(makeSection(title: "Organization", type: .organization))
                sections.append(makeSection(title: "Phone Number", type: .phoneNumber))
                sections.append(makeSection(title: "Email", type: .email))
                sections.append(makeSection(title: "URL", type: .url))
                sections.append(makeSection(title: "Address", type: .address))
                // FIXME: Add images
            }
            
            self.sections = sections
            
            for i in 0 ..< sections.count {
                if sections[i].values.count > 0 {
                    self.activeSections.append(i)
                }
            }
            
            tableView.reloadData()
        }
        catch {
            print("Cannot fetch document: \(error)")
        }
    }
    
    private func saveDocument() {
        
        // FIXME: Fetch and update fragments on background context to maintain synchronization.
        coreData.saveNow()
    }
    
    private func scanDocument() {
        scanner.scan(document: documentIdentifier) { (state) in
            DispatchQueue.main.async {
                self.handleScannerState(state)
            }
        }
    }
    
    private func handleScannerState(_ state: ScannerService.State) {
        switch state {
        case .pending:
            print("pending")
            
        case .active:
            print("active")
            scanButton.isHidden = true
            activityIndicatorView.startAnimating()
            
        case .completed:
            print("completed")
            scanButton.isHidden = false
            activityIndicatorView.stopAnimating()
            loadDocument()
        }
    }
    
    // MARK: Table view
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return activeSections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let numberOfItems = self.section(at: section).values.count
        
        if isEditing {
            return numberOfItems + 1
        }
        else {
            return numberOfItems
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.section(at: section).title
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = self.section(at: indexPath.section)
        
        if isEditing && (indexPath.row == section.values.count) {
            return self.tableView(tableView, cellForBlankTextFragmentOfType: section.type, at: indexPath)
        }
        
        let fragment = section.values[indexPath.row]
        
        switch fragment.type {
            
        case .face, .logo:
            return self.tableView(tableView, cellForImageFragment:fragment, at: indexPath)
            
        default:
            return self.tableView(tableView, cellForTextFragment:fragment, at: indexPath)
        }
    }
    
    private func tableView(_ tableView: UITableView, cellForBlankTextFragmentOfType type: FragmentType, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: basicCellIdentifier, for: indexPath) as! BasicFragmentCell
        
        let title: String
        switch type {
        case .address:
            title = "Address"
            
        case .email:
            title = "Email"
            
        case .face:
            title = "Name"
            
        case .logo:
            title = "Brand"
            
        case .note:
            title = "Note"
            
        case .organization:
            title = "Organization"
            
        case .person:
            title = "Name"
            
        case .phoneNumber:
            title = "Phone Number"
            
        case .url:
            title = "URL"
            
        case .unknown:
            title = "Text"
        }
        cell.contentTextField.placeholder = title
        cell.editingEnabled = true
        configureCell(cell, withType: type)
        cell.editingAccessoryType = .none
        cell.delegate = self
        
        return cell
    }
    
    private func tableView(_ tableView: UITableView, cellForTextFragment fragment: Fragment, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: basicCellIdentifier, for: indexPath) as! BasicFragmentCell
        cell.delegate = self
        cell.contentTextField.text = fragment.value
        cell.editingEnabled = isEditing
        configureCell(cell, withType: fragment.type)
        cell.showsReorderControl = true
        
        switch fragment.type {
        case .phoneNumber, .email:
            cell.accessoryType = .detailButton
            
        default:
            cell.accessoryType = .none
        }
        cell.editingAccessoryType = .none
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let section = self.section(at: indexPath)
        let fragment = section.values[indexPath.row]
        
        switch fragment.type {
        case .phoneNumber:
            if let value = fragment.value {
                
                // FIXME: Clean URL
//                NSString *cleanedString = [[phoneNumber componentsSeparatedByCharactersInSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789-+()"] invertedSet]] componentsJoinedByString:@""];
//                NSURL *telURL = [NSURL URLWithString:[NSString stringWithFormat:@"tel:%@", cleanedString]];
                if let url = URL(string: "tel:\(value)") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
            
        case .email:
            if let email = fragment.value, MFMailComposeViewController.canSendMail() {
                let controller = MFMailComposeViewController()
                controller.setToRecipients([email])
                controller.mailComposeDelegate = self
                present(controller, animated: true, completion: nil)
            }
            
        default:
            break
        }
    }
    
    private func tableView(_ tableView: UITableView, cellForImageFragment fragment: Fragment, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: imageCellIdentifier, for: indexPath) as! ImageFragmentCell
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        let section = self.section(at: indexPath)
        if indexPath.row == section.values.count {
            return false
        }
        else {
            return true
        }
    }
    
    private func configureCell(_ cell: BasicFragmentCell, withType type: FragmentType) {
        cell.colorView.backgroundColor = type.color
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        if isEditing {
            let section = self.section(at: indexPath.section)
            if indexPath.row == section.values.count {
                return .insert
            }
            else {
                return .delete
            }
        }
        else {
            return .none
        }
    }
    
//    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
//        var output = [UITableViewRowAction]()
//        
//        let section = self.section(at: indexPath.section)
//        let fragment = section.values[indexPath.row]
//        
//        switch fragment.type {
//            
//        case .phoneNumber:
//            output.append(
//                UITableViewRowAction(
//                    style: .default,
//                    title: "Call",
//                    handler: { (action, indexPath) in
//                        if let value = fragment.value, let url = URL(string: value) {
//                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
//                        }
//                })
//            )
//            
//        default:
//            break
//        }
//        
//        if output.count == 0 {
//            return nil
//        }
//        
//        return output
//    }
    
    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        let sourceSection = self.section(at: sourceIndexPath.section)
        let destinationSection = self.section(at: proposedDestinationIndexPath.section)
        
        let limit: Int
        
        if sourceIndexPath.section == proposedDestinationIndexPath.section {
            // Moving within same section
            limit = destinationSection.values.count - 1
        }
        else {
            // Moving to a different section
            limit = destinationSection.values.count
        }
        
        let index = min(limit, proposedDestinationIndexPath.row)
        return IndexPath(row: index, section: proposedDestinationIndexPath.section)
    }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let sourceSection = self.section(at: sourceIndexPath.section)
        let destinationSection = self.section(at: destinationIndexPath.section)
        let fragment = sourceSection.values.remove(at: sourceIndexPath.row)
        fragment.type = destinationSection.type
        destinationSection.values.insert(fragment, at: destinationIndexPath.row)
        sourceSection.updateOrdering()
        destinationSection.updateOrdering()
        saveDocument()
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        let section = self.section(at: indexPath.section)
        
        switch editingStyle {
            
        case .none:
            break
            
        case .delete:
            delete(at: indexPath)
            
        case .insert:
            if let cell = tableView.cellForRow(at: indexPath) as? BasicFragmentCell, let text = cell.contentTextField.text, !text.isEmpty {
                cell.contentTextField.text = nil
                insert(value: text, at: indexPath)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let headerView = view as? UITableViewHeaderFooterView else {
            return
        }
        
        headerView.backgroundView?.backgroundColor = UIColor(white: 0.10, alpha: 1.0)
        headerView.textLabel?.textColor = UIColor.white
    }
    
    func textCell(cell: BasicFragmentCell, textDidChange text: String?) {

        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }
        
        let section = self.section(at: indexPath.section)
        
        if indexPath.row == section.values.count {
            insert(value: text, at: indexPath)
            cell.contentTextField.text = nil
        }
        else {
            if text?.isEmpty ?? true {
                delete(at: indexPath)
            }
            else {
                update(value: text, at: indexPath)
            }
        }
        
        coreData.saveNow()
    }
    
    func delete(at indexPath: IndexPath) {
        let section = self.section(at: indexPath.section)
        let context = coreData.mainContext
        let fragment = section.values[indexPath.row]
        context.delete(fragment)
        coreData.saveNow() { success in
            if success {
                section.remove(at: indexPath.row)
                self.tableView.beginUpdates()
                if section.values.count == 0 {
                    self.activeSections.remove(at: indexPath.section)
                    self.tableView.deleteSections(IndexSet(integer: indexPath.section), with: .automatic)
                }
                else {
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                }
                self.tableView.endUpdates()
            }
        }
    }
    
    func update(value: String?, at indexPath: IndexPath) {
        let section = self.section(at: indexPath.section)
        let fragment = section.values[indexPath.row]
        fragment.value = value
        coreData.saveNow()
    }
    
    func insert(value: String?, at indexPath: IndexPath) {
        let section = self.section(at: indexPath.section)
        let context = coreData.mainContext
        do {
            let fragment = Fragment(type: section.type, value: value, context: context)
            fragment.document = try context.documents(withIdentifier: documentIdentifier).first
            try context.save()
            coreData.saveNow() { success in
                if success {
                    section.append(fragment)
                    self.tableView.beginUpdates()
                    self.tableView.insertRows(at: [indexPath], with: .automatic)
                    self.tableView.endUpdates()
                }
            }
        }
        catch {
            print("Cannot insert item: \(error)")
        }
    }
    
    func section(at indexPath: IndexPath) -> Section {
        return section(at: indexPath.section)
    }
    
    func section(at index: Int) -> Section {
        return sections[activeSections[index]]
    }
}

extension DocumentViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        dismiss(animated: true, completion: nil)
    }
}
