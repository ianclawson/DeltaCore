//
//  GameView.swift
//  DeltaCore
//
//  Created by Riley Testut on 3/16/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import UIKit
import CoreImage
//import GLKit
import MetalKit
import AVFoundation

// Create wrapper class to prevent exposing GLKView (and its annoying deprecation warnings) to clients.
//private class GameViewGLKViewDelegate: NSObject, GLKViewDelegate
private class GameViewMTKViewDelegate: NSObject, MTKViewDelegate
{
    weak var gameView: GameView?
    
    init(gameView: GameView)
    {
        self.gameView = gameView
    }
    
//    func glkView(_ view: GLKView, drawIn rect: CGRect)
//    func mtkView(_ view: MTKView, drawIn rect: CGRect)
//    {
////        self.gameView?.glkView(view, drawIn: rect)
//        self.gameView?.mtkView(view, drawIn: rect)
//    }
    
    // MTKViewDelegate
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        self.gameView?.draw(in: view)
    }
}

public enum SamplerMode
{
    case linear
    case nearestNeighbor
}

public class GameView: UIView
{
    @NSCopying public var inputImage: CIImage? {
        didSet {
            if self.inputImage?.extent != oldValue?.extent
            {
                DispatchQueue.main.async {
                    self.setNeedsLayout()
                }
            }
            
            self.update()
        }
    }
    
    @NSCopying public var filter: CIFilter? {
        didSet {
            self.update()
        }
    }
    
    public var samplerMode: SamplerMode = .nearestNeighbor {
        didSet {
            self.update()
        }
    }
    
    public var outputImage: CIImage? {
        guard let inputImage = self.inputImage else { return nil }
        
        var image: CIImage? = inputImage.clampedToExtent()
        
        switch self.samplerMode
        {
        case .linear: image = inputImage.samplingLinear()
        case .nearestNeighbor: image = inputImage.samplingNearest()
        }
                
        if let filter = self.filter
        {
            filter.setValue(image, forKey: kCIInputImageKey)
            image = filter.outputImage
        }
        
        let outputImage = image?.cropped(to: inputImage.extent)
        return outputImage
    }
    
//    internal var eaglContext: EAGLContext {
//        get { return self.glkView.context }
//        set {
//            // For some reason, if we don't explicitly set current EAGLContext to nil, assigning
//            // to self.glkView may crash if we've already rendered to a game view.
//            EAGLContext.setCurrent(nil)
//
//            self.glkView.context = newValue
//            self.context = self.makeContext()
//        }
//    }
    private lazy var context: CIContext = self.makeContext()
        
//    private let glkView: GLKView
//    private lazy var glkViewDelegate = GameViewGLKViewDelegate(gameView: self)
    private let mtkView: MTKView
    private lazy var mtkViewDelegate = GameViewMTKViewDelegate(gameView: self)
    
    public override init(frame: CGRect)
    {
//        let eaglContext = EAGLContext(api: .openGLES2)!
//        self.glkView = GLKView(frame: CGRect.zero, context: eaglContext)
//
//        super.init(frame: frame)
//
//        self.initialize()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Unable to create metal device. Aborting.")
        }
        
        self.mtkView = MTKView(frame: CGRect.zero, device: device)
        
        super.init(frame: frame)

        self.initialize()
    }
    
    public required init?(coder aDecoder: NSCoder)
    {
//        let eaglContext = EAGLContext(api: .openGLES2)!
//        self.glkView = GLKView(frame: CGRect.zero, context: eaglContext)
//
//        super.init(coder: aDecoder)
//
//        self.initialize()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Unable to create metal device. Aborting.")
        }
        
        self.mtkView = MTKView(frame: CGRect.zero, device: device)
        
        super.init(coder: aDecoder)
        
        self.initialize()
        
    }
    
    private func initialize()
    {        
//        self.glkView.frame = self.bounds
//        self.glkView.delegate = self.glkViewDelegate
//        self.glkView.enableSetNeedsDisplay = false
//        self.addSubview(self.glkView)
        self.mtkView.frame = self.bounds
        self.mtkView.delegate = self.mtkViewDelegate
        self.mtkView.enableSetNeedsDisplay = false
        self.addSubview(self.mtkView)
    }
    
    public override func didMoveToWindow()
    {
        if let window = self.window
        {
//            self.glkView.contentScaleFactor = window.screen.scale
            self.mtkView.contentScaleFactor = window.screen.scale
            self.update()
        }
    }
    
    public override func layoutSubviews()
    {
        super.layoutSubviews()
        
        if let outputImage = self.outputImage
        {
            let frame = AVMakeRect(aspectRatio: outputImage.extent.size, insideRect: self.bounds)
//            self.glkView.frame = frame
            self.mtkView.frame = frame
            
//            self.glkView.isHidden = false
            self.mtkView.isHidden = false
        }
        else
        {
            let frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
//            self.glkView.frame = frame
            self.mtkView.frame = frame
            
//            self.glkView.isHidden = true
            self.mtkView.isHidden = true
        }
    }
}

public extension GameView
{
    func snapshot() -> UIImage?
    {
        // Unfortunately, rendering CIImages doesn't always work when backed by an OpenGLES texture.
        // As a workaround, we simply render the view itself into a graphics context the same size
        // as our output image.
        //
        // let cgImage = self.context.createCGImage(outputImage, from: outputImage.extent)
        
        guard let outputImage = self.outputImage else { return nil }

        let rect = CGRect(origin: .zero, size: outputImage.extent.size)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        
        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        
        let snapshot = renderer.image { (context) in
//            self.glkView.drawHierarchy(in: rect, afterScreenUpdates: false)
            self.mtkView.drawHierarchy(in: rect, afterScreenUpdates: false)
        }
        
        return snapshot
    }
}

private extension GameView
{
    func makeContext() -> CIContext
    {
//        let context = CIContext(eaglContext: self.glkView.context, options: [.workingColorSpace: NSNull()])
        let context = CIContext(mtlDevice: self.mtkView.device!, options: [.workingColorSpace : NSNull()])
        return context
    }
    
    func update()
    {
        // Calling display when outputImage is nil may crash for OpenGLES-based rendering.
        guard self.outputImage != nil else { return }
                
//        self.glkView.display()
        self.display()
    }
}

private extension GameView
{
//    func glkView(_ view: GLKView, drawIn rect: CGRect)
//    {
//        glClearColor(0.0, 0.0, 0.0, 1.0)
//        glClear(UInt32(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
//
//        if let outputImage = self.outputImage
//        {
//            let bounds = CGRect(x: 0, y: 0, width: self.glkView.drawableWidth, height: self.glkView.drawableHeight)
//            self.context.draw(outputImage, in: bounds, from: outputImage.extent)
//        }
//    }
    
//    func mtkView(_ view: MTKView, drawIn rect: CGRect)
    func draw(in view: MTKView)
    {
        
//        glClearColor(0.0, 0.0, 0.0, 1.0)
//        glClear(UInt32(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        view.currentRenderPassDescriptor?.depthAttachment.loadAction = .clear
        view.currentRenderPassDescriptor?.depthAttachment.clearDepth = 1.0
        
        if let outputImage = self.outputImage
        {
//            let bounds = CGRect(x: 0, y: 0, width: self.glkView.drawableWidth, height: self.glkView.drawableHeight)
            let bounds = CGRect(x: 0, y: 0, width: self.mtkView.drawableSize.width, height: self.mtkView.drawableSize.height)
            self.context.draw(outputImage, in: bounds, from: outputImage.extent)
        }
    }
}

private extension GameView {
    func display()
    {
        // TODO: replace display logic with MTK equivilent
    }
}

///
///import UIKit
///import CoreImage
/////import GLKit
///import AVFoundation
///
///// Create wrapper class to prevent exposing GLKView (and its annoying deprecation warnings) to clients.
///private class GameViewGLKViewDelegate: NSObject, GLKViewDelegate
///{
///    weak var gameView: GameView?
///
///    init(gameView: GameView)
///    {
///        self.gameView = gameView
///    }
///
///    func glkView(_ view: GLKView, drawIn rect: CGRect)
///    {
///        self.gameView?.glkView(view, drawIn: rect)
///    }
///}
///
///public enum SamplerMode
///{
///    case linear
///    case nearestNeighbor
///}
///
///public class GameView: UIView
///{
///    @NSCopying public var inputImage: CIImage? {
///        didSet {
///            if self.inputImage?.extent != oldValue?.extent
///            {
///                DispatchQueue.main.async {
///                    self.setNeedsLayout()
///                }
///            }
///
///            self.update()
///        }
///    }
///
///    @NSCopying public var filter: CIFilter? {
///        didSet {
///            self.update()
///        }
///    }
///
///    public var samplerMode: SamplerMode = .nearestNeighbor {
///        didSet {
///            self.update()
///        }
///    }
///
///    public var outputImage: CIImage? {
///        guard let inputImage = self.inputImage else { return nil }
///
///        var image: CIImage? = inputImage.clampedToExtent()
///
///        switch self.samplerMode
///        {
///        case .linear: image = inputImage.samplingLinear()
///        case .nearestNeighbor: image = inputImage.samplingNearest()
///        }
///
///        if let filter = self.filter
///        {
///            filter.setValue(image, forKey: kCIInputImageKey)
///            image = filter.outputImage
///        }
///
///        let outputImage = image?.cropped(to: inputImage.extent)
///        return outputImage
///    }
///
///    internal var eaglContext: EAGLContext {
///        get { return self.glkView.context }
///        set {
///            // For some reason, if we don't explicitly set current EAGLContext to nil, assigning
///            // to self.glkView may crash if we've already rendered to a game view.
///            EAGLContext.setCurrent(nil)
///
///            self.glkView.context = newValue
///            self.context = self.makeContext()
///        }
///    }
///    private lazy var context: CIContext = self.makeContext()
///
///    private let glkView: GLKView
///    private lazy var glkViewDelegate = GameViewGLKViewDelegate(gameView: self)
///
///    public override init(frame: CGRect)
///    {
///        let eaglContext = EAGLContext(api: .openGLES2)!
///        self.glkView = GLKView(frame: CGRect.zero, context: eaglContext)
///
///        super.init(frame: frame)
///
///        self.initialize()
///    }
///
///    public required init?(coder aDecoder: NSCoder)
///    {
///        let eaglContext = EAGLContext(api: .openGLES2)!
///        self.glkView = GLKView(frame: CGRect.zero, context: eaglContext)
///
///        super.init(coder: aDecoder)
///
///        self.initialize()
///    }
///
///    private func initialize()
///    {
///        self.glkView.frame = self.bounds
///        self.glkView.delegate = self.glkViewDelegate
///        self.glkView.enableSetNeedsDisplay = false
///        self.addSubview(self.glkView)
///    }
///
///    public override func didMoveToWindow()
///    {
///        if let window = self.window
///        {
///            self.glkView.contentScaleFactor = window.screen.scale
///            self.update()
///        }
///    }
///
///    public override func layoutSubviews()
///    {
///        super.layoutSubviews()
///
///        if let outputImage = self.outputImage
///        {
///            let frame = AVMakeRect(aspectRatio: outputImage.extent.size, insideRect: self.bounds)
///            self.glkView.frame = frame
///
///            self.glkView.isHidden = false
///        }
///        else
///        {
///            let frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height)
///            self.glkView.frame = frame
///
///            self.glkView.isHidden = true
///        }
///    }
///}
///
///public extension GameView
///{
///    func snapshot() -> UIImage?
///    {
///        // Unfortunately, rendering CIImages doesn't always work when backed by an OpenGLES texture.
///        // As a workaround, we simply render the view itself into a graphics context the same size
///        // as our output image.
///        //
///        // let cgImage = self.context.createCGImage(outputImage, from: outputImage.extent)
///
///        guard let outputImage = self.outputImage else { return nil }
///
///        let rect = CGRect(origin: .zero, size: outputImage.extent.size)
///
///        let format = UIGraphicsImageRendererFormat()
///        format.scale = 1.0
///        format.opaque = true
///
///        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
///
///        let snapshot = renderer.image { (context) in
///            self.glkView.drawHierarchy(in: rect, afterScreenUpdates: false)
///        }
///
///        return snapshot
///    }
///}
///
///private extension GameView
///{
///    func makeContext() -> CIContext
///    {
///        let context = CIContext(eaglContext: self.glkView.context, options: [.workingColorSpace: NSNull()])
///        return context
///    }
///
///    func update()
///    {
///        // Calling display when outputImage is nil may crash for OpenGLES-based rendering.
///        guard self.outputImage != nil else { return }
///
///        self.glkView.display()
///    }
///}
///
////private extension GameView
////{
////    func glkView(_ view: GLKView, drawIn rect: CGRect)
////    {
////        glClearColor(0.0, 0.0, 0.0, 1.0)
////        glClear(UInt32(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
////
////        if let outputImage = self.outputImage
////        {
////            let bounds = CGRect(x: 0, y: 0, width: self.glkView.drawableWidth, height: self.glkView.drawableHeight)
////            self.context.draw(outputImage, in: bounds, from: outputImage.extent)
////        }
////    }
////}////
