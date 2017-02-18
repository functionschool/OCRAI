//
//  ScanOperation.swift
//  CardScanner
//
//  Created by Luke Van In on 2017/02/17.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import Foundation
import CoreLocation

class ScanOperation: AsyncOperation {
    
    private let identifier: String
    private let service: ScannerService
    private let coreData: CoreDataStack
    private let progress: ScannerService.ProgressHandler
    private let queue: DispatchQueue
    private let group: DispatchGroup
    
    private var state: ScannerService.State = .pending {
        didSet {
            self.progress(state)
        }
    }
    
    init(document identifier: String, service: ScannerService, coreData: CoreDataStack, progress: @escaping ScannerService.ProgressHandler) {
        self.identifier = identifier
        self.service = service
        self.coreData = coreData
        self.progress = progress
        self.queue = DispatchQueue(label: "ScannerServiceOperation")
        self.group = DispatchGroup()
    }
    
    override func cancel() {
        // FIXME: Cancel pending operations
        super.cancel()
    }
    
    override func execute(completion: @escaping () -> Void) {
        state = .active
        annotate()
        group.notify(queue: queue) { [coreData] in
            DispatchQueue.main.async {
                coreData.saveNow() {
                    self.state = .completed
                }
            }
        }
    }
    
    private func annotate() {
        group.enter()
        coreData.performBackgroundChanges() { [identifier, group] context in
            if let data = try context.documents(withIdentifier: identifier).first?.imageData {
                self.annotateImage(data as Data)
            }
            group.leave()
        }
    }
    
    private func annotateImage(_ image: Data) {
        group.enter()
        service.annotateImage(image: image) { response in
            if let response = response {
                self.handleImageAnnotationsResponse(response)
            }
            self.group.leave()
        }
    }
    
    private func handleImageAnnotationsResponse(_ response: ImageAnnotationResponse) {
        processAnnotations(response.faceAnnotations, process: imageAnnotationProcessor(.face))
        processAnnotations(response.logoAnnotations, process: imageAnnotationProcessor(.logo))
        processAnnotations(response.codeAnnotations, process: processCodeAnnotation)
        processTextAnnotations(response.textAnnotations)
    }
    
    private func processAnnotations(_ annotations: [Annotation], process: (Annotation) -> Void) {
        for annotation in annotations {
            process(annotation)
        }
    }
    
    private func imageAnnotationProcessor(_ type: ImageFragmentType) -> (Annotation) -> Void {
        return { annotation in
            // FIXME: Clip logo from source image according to bounding polygon. Import clipped image as image fragment.
        }
    }
    
    private func processCodeAnnotation(_ annotation: Annotation) {
        // FIXME: Import URLs, vCard and text from machine codes.
    }
    
    private func processTextAnnotations(_ annotations: [Annotation]) {
        guard let annotation = annotations.first else {
            return
        }
        let text = annotation.content
        group.enter()
        service.annotateText(text: text) { response in
            if let response = response {
                self.handleTextAnnotationsResponse(response)
            }
            self.group.leave()
        }
    }
    
    private func handleTextAnnotationsResponse(_ response: TextAnnotationResponse) {
        processEntities(response.personEntities, process: entityProcessor(.person))
        processEntities(response.organizationEntities, process: entityProcessor(.organization))
        processEntities(response.phoneEntities, process: entityProcessor(.phoneNumber))
        processEntities(response.urlEntities, process: entityProcessor(.url))
        processEntities(response.emailEntities, process: entityProcessor(.email))
        processEntities(response.addressEntities, process: processAddressEntity)
    }
    
    // MARK: Generic entities
    
    private func entityProcessor(_ type: TextFragmentType) -> (Entity) -> Void {
        return { [identifier, group, coreData] entity in
            group.enter()
            coreData.performBackgroundChanges() { context in
                let fragment = TextFragment(
                    type: type,
                    value: entity.content,
                    context: context
                )
                fragment.document = try context.documents(withIdentifier: identifier).first
                do {
                    try context.save()
                }
                catch {
                    print("Cannot import entity \(type): \(error)")
                }
                group.leave()
            }
        }
    }
    
    // MARK: Address
    
    private func processAddressEntity(_ entity: Entity) {
        group.enter()
        resolveAddress(address: entity.content) { (placemark) in
            if let placemark = placemark {
                self.addAddress(placemark)
            }
            self.group.leave()
        }
    }
    
    private func resolveAddress(address: String, completion: @escaping (CLPlacemark?) -> Void) {
        service.resolveAddress(address: address) { addresses in
            completion(addresses?.first)
        }
    }
    
    private func addAddress(_ placemark: CLPlacemark) {
        group.enter()
        coreData.performBackgroundChanges { [identifier] (context) in
            let fragment = LocationFragment(
                placemark: placemark,
                context: context
            )
            fragment.document = try context.documents(withIdentifier: identifier).first
            do {
                try context.save()
            }
            catch {
                print("Cannot add address: \(error)")
            }
            self.group.leave()
        }
    }
    
    // MARK: Common
    
    private func processEntities(_ entities: [Entity], process: (Entity) -> Void) {
        for entity in entities {
            process(entity)
        }
    }
}