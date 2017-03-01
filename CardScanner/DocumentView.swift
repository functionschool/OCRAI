//
//  DocumentView.swift
//  CardScanner
//
//  Created by Luke Van In on 2017/02/28.
//  Copyright © 2017 Luke Van In. All rights reserved.
//

import UIKit

class DocumentView: UIView {
    
    var image: UIImage? {
        didSet {
            documentImageView.image = image
        }
    }
    
    var fragments: [Fragment]? {
        didSet {
            invalidateAnnotations()
        }
    }
    
    @IBOutlet weak var documentImageView: UIImageView!
    @IBOutlet weak var annotationsImageView: UIImageView!
    
    func invalidateAnnotations() {
        setNeedsLayout()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard let imageSize = image?.size else {
            annotationsImageView.image = nil
            return
        }
        
        let scale = calculateScale(from: imageSize, to: bounds.size)
        let actualSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        
        annotationsImageView.image = renderAnnotations(size: actualSize, scale: scale)
        
        let origin = CGPoint(
            x: (bounds.size.width - actualSize.width) * 0.5,
            y: (bounds.size.height - actualSize.height) * 0.5
        )
        let frame = CGRect(origin: origin, size: actualSize)
        documentImageView.frame = frame
        annotationsImageView.frame = frame
    }
    
    private func renderAnnotations(size: CGSize, scale: CGFloat) -> UIImage? {
        
        guard let fragments = self.fragments else {
            return nil
        }
        
        let renderer = AnnotationsRenderer(
            size: size,
            scale: scale,
            fragments: fragments
        )

        let output = renderer.render()
        return output
    }
    
    private func calculateScale(from sourceSize: CGSize, to targetSize: CGSize) -> CGFloat {
        
        let sourceAspect = sourceSize.width / sourceSize.height
        let targetAspect = targetSize.width / targetSize.height
        let scale: CGFloat
        
        if sourceAspect > targetAspect {
            // Image is wider aspect than available area.
            // Scale to width.
            scale = targetSize.width / sourceSize.width
        }
        else {
            // Image is narrower aspect than available area.
            // Scale to height.
            scale = targetSize.height / sourceSize.height
        }
        
        return scale
    }
}