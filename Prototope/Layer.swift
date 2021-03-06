//
//  Layer.swift
//  Prototope
//
//  Created by Andy Matuschak on 10/3/14.
//  Copyright (c) 2014 Khan Academy. All rights reserved.
//


#if os(iOS)
	import UIKit
	public typealias SystemView = UIView
	#else
	import AppKit
	public typealias SystemView = NSView
#endif

/**
	Layers are the fundamental building block of Prototope.

	A layer displays content (a color, an image, etc.) and can route touch events.

	Layers are stored in a tree. It's possible to make a layer without a parent, but
	only layers in the tree starting at Layer.root will be displayed.

	An example of making a red layer, ready for display:

		let redLayer = Layer(parent: Layer.root)
		redLayer.backgroundColor = Color.red
		redLayer.frame = Rect(x: 50, y: 50, width: 100, height: 100)
*/
public class Layer: Equatable {

	// MARK: Creating and identifying layers

	/** The root layer of the scene. Defines the global coordinate system. */
	public class var root: Layer! { return Environment.currentEnvironment?.rootLayer }

	/** Creates a layer with an optional parent and name. */
	public init(parent: Layer? = Layer.root, name: String? = nil, viewClass: SystemView.Type? = nil) {
		self.parent = parent ?? Layer.root
		self.name = name

		if let viewClass = viewClass {
			self.view = viewClass.init()
		} else {
			self.view = TouchForwardingImageView() // TODO: dynamically switch the view type depending on whether we're using an image or not
		}
		
		#if os(iOS)
		self.view.multipleTouchEnabled = true
		self.view.userInteractionEnabled = true
		#endif

		self.parentDidChange()

		self.frame = Rect(x: 0, y: 0, width: 100, height: 100)
	}

	/** Convenience initializer; makes a layer which displays an image by name.
		The layer will adopt its size from the image and its name from imageName. */
	public convenience init(parent: Layer?, imageName: String) {
		self.init(parent: parent, name: imageName)
		self.image = Image(name: imageName)
		imageDidChange()
	}
	
	
	/** Convenience initializer; makes a layer which displays the given image.
		The layer will adopt its size from the image. */
	public convenience init(parent: Layer?, image: Image) {
		self.init(parent: parent)
		self.image = image
		imageDidChange()
	}
	

	/** Creates a Prototope Layer by wrapping a CALayer. The result may not have
	access to all the normal Prototope functionality--beware! You should mostly
	control this Layer via CALayer's APIs, not Prototope's. */
	public convenience init(wrappingCALayer: CALayer, name: String? = nil) {
		let wrappingView = CALayerWrappingView(wrappedLayer: wrappingCALayer)
		self.init(wrappingView: wrappingView, name: name)
	}

	/** Layers have an optional name that can be used to find them via various
		convenience methods. Defaults to nil. */
	public let name: String?

	// MARK: Layer hierarchy access and manipulation

	/** The layer's parent layer. The parent layer will be nil when the layer is
		not attached to a hierarchy, or when the receiver is the root layer.

		Setting this property will move the layer to a new parent (or remove it
		from the layer hierarchy if you set the parent to nil. */
	public weak var parent: Layer? {
		willSet {
			if let parent = self.parent {
				parent.sublayers.removeAtIndex(parent.sublayers.indexOf(self)!)
				view.removeFromSuperview()
			}
		}
		didSet {
			parentDidChange()
		}
	}

	/** An array of all this layer's sublayers. */
	public private(set) var sublayers: [Layer] = []

	/** Removes all of the receivers' sublayers from the hierarchy. */
	public func removeAllSublayers() {
		// TODO: This could be way faster.
		for sublayer in sublayers {
			sublayer.parent = nil
		}
	}
	
	#if os(iOS)
	/** Brings the layer to the front of all sibling layers. */
	public func comeToFront() {
		if let parentView = self.parentView {
			parentView.bringSubviewToFront(self.view)
			self.parent?.sublayers.insert(self.parent!.sublayerAtFront!, atIndex: 0)
		}
	}
	#else
	public func comeToFront() {
		if let parentView = self.parentView {
			// TODO(jb): Should be doing this with parentView.sortSubviewsUsingFunction() but I don't want to deal with C function pointers in Swift / I don't think I can do this until Swift 2.0
			let subview = self.view
			subview.removeFromSuperview()
			parentView.addSubview(subview)
		}
	}
	#endif

	/** Returns the sublayer which will be visually ordered to the front. */
	public var sublayerAtFront: Layer? { return sublayers.last }

	/** Returns the sublayer whose name matches the argument, or nil if it is not found. */
	public func sublayerNamed(name: String) -> Layer? {
		return sublayers.filter{ $0.name == name }.first
	}

	/** Returns the descendent (at any level) whose name matches the argument, or nil
		if it is not found. */
	public func descendentNamed(name: String) -> Layer? {
		if self.name == name {
			return self
		}

		for sublayer in sublayers {
			if let match = sublayer.descendentNamed(name) {
				return match
			}
		}

		return nil
	}

	/** Attempts to find a layer at a particular named path by calling sublayerNamed
		once at each level, for each element in pathElements. Returns nil if not found.

		Example:
			let a = Layer()
			let b = Layer(parent: a, name: "foo")
			let c = Layer(parent: b, name: "bar")
			a.descendentAtPath(["foo", "bar"]) // returns c
			a.descendentAtPath(["foo", "quux"]) // returns nil */
	public func descendentAtPath(pathElements: [String]) -> Layer? {
		return pathElements.reduce(self) { $0?.sublayerNamed($1) }
	}

	/** Attempts to find a layer in the series of parent layers between the receiver and
		the root layer which has a given name. Returns nil if none is found. */
	public func ancestorNamed(name: String) -> Layer? {
		var currentLayer = parent
		while currentLayer != nil {
			if currentLayer!.name == name {
				return currentLayer
			}
			currentLayer = currentLayer!.parent
		}
		return nil
	}

    /** Sets the zPosition of the layer. Higher values go towards the screen as the
        z axis increases towards your face. Measured in points and defaults to 0.
        Animatable, but not yet with dynamic animators. */
    public var zPosition: Double {
		get { return Double(layer.zPosition) }
		set { layer.zPosition = CGFloat(newValue) }
	}

	// MARK: Geometry

	/** The x position of the layer's anchor point (by default the center), relative to
		the origin of its parent layer and expressed in the parent coordinate space.
		Animatable. */
	public var x: Double {
		get { return Double(layer.position.x) }
		set { layer.position.x = CGFloat(newValue) }
	}

	/** The y position of the layer's anchor point (by default the center), relative to
		the origin of its parent layer and expressed in the parent coordinate space.
		Animatable. */
	public var y: Double {
		get { return Double(layer.position.y) }
		set { layer.position.y = CGFloat(newValue) }
	}

    /** The position of the layer's origin point (the upper left-hand corner), 
        relative to the origin of its parent layer and expressed in the parent coordinate space. */
	#if os(iOS) // TODO(jb): Why can't I put this #if block inside the var declaration?
    public var origin: Point {
        get { return Point(layer.frame.origin) }
        set { layer.frame.origin = CGPoint(newValue) }
	}
	#else
	public var origin: Point {
		get { return Point(view.frame.origin) }
		set { view.setFrameOrigin(CGPoint(newValue)) }
    }
	#endif

	/** The position of the layer's anchor point (by default the center), relative to the
		origin of its parent layer and expressed in the parent coordinate space.
		Animatable. */
	#if os(iOS)
	public var position: Point {
		get { return Point(layer.position) }
		set { layer.position = CGPoint(newValue) }
	}
	#else
	public var position: Point {
		get { return view.frameCenter }
		set { view.frameCenter = newValue }
	}
	#endif
	

	/** The layer's width, expressed in its own coordinate space. Animatable (but not yet
		via the dynamic animators). */
	public var width: Double {
		get { return bounds.size.width }
		set { bounds.size.width = newValue }
	}

	/** The layer's height, expressed in its own coordinate space. Animatable (but not yet
		via the dynamic animators). */
	public var height: Double {
		get { return bounds.size.height }
		set { bounds.size.height = newValue }
	}

	/** The layer's size, expressed in its own coordinate space. Animatable. */
	public var size: Size {
		get { return Size(layer.bounds.size) }
		set { layer.bounds.size = CGSize(newValue) }
	}

	/** The origin and extent of the layer expressed in its parent layer's coordinate space.
		Animatable. */
	public var frame: Rect {
		get {
			// TODO(jb): Do we need to make this distinction? Can't UIKit's version just use view.frame instead of layer.frame?
			// TODO(jb): Treat self.bounds the same way as here.
			#if os(iOS)
			return Rect(layer.frame)
			#else
			return Rect(self.view.frame)
			#endif
		}
		set {
			#if os(iOS)
			layer.frame = CGRect(newValue)
			#else
			self.view.frame = CGRect(newValue)
			#endif
		}
	}

	/** The visible region of the layer, expressed in its own coordinate space. The x and y
		position define the visible origin (e.g. if you set bounds.y = 50, the top 50 pixels
		of the layer's image will be cut off); the width and height define its size.
		Animatable. */
	public var bounds: Rect {
		get { return Rect(layer.bounds) }
		set { layer.bounds = CGRect(newValue) }
	}

	/** A layer's position is defined in terms of its anchor point, which defaults to the center.
		e.g. if you changed the anchor point to the upper-left hand corner, the layer's position
		would define the position of that corner.

		The anchor point also defines the point about which transformations are applied. e.g. for
		rotation, it defines the center of rotation.

		The anchor point is specified in unit coordinates: (0, 0) is the upper-left; (1, 1) is the
		lower-right. */
	public var anchorPoint: Point {
		get { return Point(layer.anchorPoint) }
		set { layer.anchorPoint = CGPoint(newValue) }
	}

	/** The rotation of the layer specified in degrees. May be used interchangeably with
	rotationRadians. Defaults to 0. */
	public var rotationDegrees: Double {
		get {
			return rotationRadians * 180 / M_PI
		}
		set {
			rotationRadians = newValue * M_PI / 180
		}
	}

	/** The rotation of the layer specified in radians. May be used interchangeably with
	rotationDegrees. Defaults to 0. */
	public var rotationRadians: Double {
        get {
            return layer.valueForKeyPath("transform.rotation.z") as! Double
        }
		set {
            layer.setValue(newValue, forKeyPath: "transform.rotation.z")
        }
	}

	/** The scaling factor of the layer. Setting this value will set both scaleX and scaleY
	to the new value. Defaults to 1. */
	public var scale: Double {
		get { return scaleX }
		set {
			scaleX = newValue
			scaleY = newValue
		}
	}

	/** The scaling factor of the layer along the x dimension. Defaults to 1. */
	public var scaleX: Double {
        get {
            return layer.valueForKeyPath("transform.scale.x") as! Double
        }
        set {
            layer.setValue(newValue, forKeyPath: "transform.scale.x")
        }
	}

	/** The scaling factor of the layer along the y dimension. Defaults to 1. */
	public var scaleY: Double {
        get {
            return layer.valueForKeyPath("transform.scale.y") as! Double
        }
        set {
            layer.setValue(newValue, forKeyPath: "transform.scale.y")
        }
	}

	// TODO(jb): Just being lazy now, this really needs to be ported to OS X
	#if os(iOS)
	/** Returns the layer's position in the root layer's coordinate space. */
	public var globalPosition: Point {
		get {
			if let parent = parent {
				return parent.convertLocalPointToGlobalPoint(position)
			} else {
				return position
			}
		}
		set {
			if let parent = parent {
				position = parent.convertGlobalPointToLocalPoint(newValue)
			} else {
				position = newValue
			}
		}
	}

	/** Returns whether the layer contains a given point, interpreted in the root layer's
		coordinate space. */
	public func containsGlobalPoint(point: Point) -> Bool {
		return view.pointInside(CGPoint(convertGlobalPointToLocalPoint(point)), withEvent: nil)
	}

	/** Converts a point specified in the root layer's coordinate space to that same point
		expressed in the receiver's coordinate space. */
	public func convertGlobalPointToLocalPoint(globalPoint: Point) -> Point {
		return Point(view.convertPoint(CGPoint(globalPoint), fromCoordinateSpace: UIScreen.mainScreen().coordinateSpace))
	}

	/** Converts a point specified in the receiver's coordinate space to that same point
		expressed in the root layer's coordinate space. */
	public func convertLocalPointToGlobalPoint(localPoint: Point) -> Point {
		return Point(view.convertPoint(CGPoint(localPoint), toCoordinateSpace: UIScreen.mainScreen().coordinateSpace))
	}
	#endif

	// MARK: Appearance

	/** The layer's background color. Will be displayed behind images and borders, above
		shadows. Defaults to nil. Animatable. */
	public var backgroundColor: Color? {
		get { return view.backgroundColor != nil ? Color(view.backgroundColor!) : nil }
		set { view.backgroundColor = newValue?.systemColor }
	}

	/** The layer's opacity (from 0 to 1). Animatable. Defaults to 1. */
	public var alpha: Double {
		get { return Double(view.alpha) }
		set { view.alpha = CGFloat(newValue) }
	}

	/** The layer's corner radius. Setting this to a non-zero value will also cause the
		layer to be masked at its corners. Defaults to 0. */
	public var cornerRadius: Double {
		get { return Double(layer.cornerRadius) }
		set {
			layer.cornerRadius = CGFloat(newValue)
			layer.masksToBounds = self._shouldMaskToBounds()
		}
	}

	/** An optional image which the layer displays. When set, changes the layer's size to
		match the image's. Defaults to nil. */
	public var image: Image? {
		didSet { imageDidChange() }
	}

	/** The border drawn around the layer, inset into the layer's bounds, and on top of any of
		the other layer content. Respects the corner radius. Defaults to a clear border with
		a 0 width. */
	public var border: Border {
		get {
			return Border(color: Color(SystemColor(CGColor: layer.borderColor!)), width: Double(layer.borderWidth))
		}
		set {
			layer.borderColor = newValue.color.systemColor.CGColor
			layer.borderWidth = CGFloat(newValue.width)
		}
	}

	/** The shadow drawn beneath the layer. If the layer has no background color, this shadow
		will respect the alpha values of the layer's image: clear parts of the image will not
		generate a shadow. */
	public var shadow: Shadow {
		get {
			let layer = self.layer
			let color: Color
			if let shadowColor = layer.shadowColor {
				let systemColor = SystemColor(CGColor: shadowColor)
				color = Color(systemColor)
			} else {
				color = Color.black
			}
				
			return Shadow(color: color, alpha: Double(layer.shadowOpacity), offset: Size(layer.shadowOffset), radius: Double(layer.shadowRadius))
		}
		set {
			layer.shadowColor = newValue.color.systemColor.CGColor
			layer.shadowOpacity = Float(newValue.alpha)
			layer.shadowOffset = CGSize(newValue.offset)
			layer.shadowRadius = CGFloat(newValue.radius)
			layer.masksToBounds = self._shouldMaskToBounds()
		}
	}
    
	
	// TODO(jb): port masked layer stuff to OS X.
	#if os(iOS)
    /** The mask layer is used to clip or filter the contents of a layer. Those contents will be
        rendered only where the mask layer's contents are opaque. Partially transparent regions
        of the mask layer will result in partially transparent renderings of the host layer.

        The mask layer operates within the coordinate space of its host layer. In most cases,
        you'll want to set a mask layer's frame to be equal to its host's bounds.

        Be aware: mask layers do incur an additional performance cost. If the cost becomes too
        onerous, consider making flattened images of the masked content instead. */
    public var maskLayer: Layer? {
        willSet {
            newValue?.parent = nil
            newValue?.maskedLayer?.maskLayer = nil
        }
        didSet {
            view.maskView = maskLayer?.view
            maskLayer?.maskedLayer = self
        }
    }
    
    private weak var maskedLayer: Layer?
	#endif

	
	// MARK: Particles
	
	/** An array of the layer's particle emitters. */
	private var particleEmitters: [ParticleEmitter] = []
	
	
	/** Adds the particle emitter to the layer. */
	public func addParticleEmitter(particleEmitter: ParticleEmitter, forDuration duration: TimeInterval? = nil) {
		self.particleEmitters.append(particleEmitter)
		self.layer.addSublayer(particleEmitter.emitterLayer)
		particleEmitter.emitterLayer.frame = self.layer.bounds
		particleEmitter.size = self.size
		particleEmitter.position = Point(particleEmitter.emitterLayer.position)
		
		// TODO(jb): Should we disable bounds clipping on self.view.layer or instruct devs to instead emit the particles from a parent layer?
		self.layer.masksToBounds = false
		
		if let duration = duration {
			afterDuration(duration) {
				self.removeParticleEmitter(particleEmitter)
			}
		}
	}
	
	
	/** Removes the given particle emitter from the layer. */
	public func removeParticleEmitter(particleEmitter: ParticleEmitter) {
		particleEmitter.emitterLayer.removeFromSuperlayer()
		self.particleEmitters = self.particleEmitters.filter {
			(emitter: ParticleEmitter) -> Bool in
			return emitter !== particleEmitter
		}
	}
	
	
	// TODO(jb): Port touches / gestures to OS X? What makes sense here?
	#if os(iOS)
    // MARK: Touches and gestures

	/** When false, touches that hit this layer or its sublayers are discarded. Defaults
		to true. */
	public var userInteractionEnabled: Bool {
		get { return view.userInteractionEnabled }
		set { view.userInteractionEnabled = newValue }
	}

	
	/** An array of the layer's gestures. Append a gesture to this list to add it to the layer.

		Gestures are like a higher-level abstraction than the Layer touch handler API. For
		instance, a pan gesture consumes a series of touch events but does not actually begin
		until the user moves a certain distance with a specified number of fingers.

		Gestures can also be exclusive: by default, if a gesture recognizes, traditional
		touch handlers for that subtree will be cancelled. You can control this with the
		cancelsTouchesInView property. Also by default, if one gesture recognizes, it will
		prevent all other gestures involved in that touch from recognizing.

		Defaults to the empty list. */
	public var gestures: [GestureType] = [] {
		didSet {
			for gesture in gestures {
				gesture.hostLayer = self
			}
		}
	}

	/** A layer's touchesXXXHandler property is set to a closure of this type. It takes a
		dictionary whose keys are touch sequences' IDs and whose values are a touch sequence;
		it should return whether or not the event was handled. If the return value is false
		the touches event will be passed along to the parent layer. */
	public typealias TouchesHandler = [UITouchID: TouchSequence<UITouchID>] -> Bool

	/** A layer's touchXXXHandler property is set to a closure of this type. These handlers
		can be used as more convenient variants of the touchesXXXHandlers for situations in
		which the touches can be considered independently. These handlers are passed a touch
		sequence and don't need to return a value.

		If multiple touches are involved in a single event for a single layer, this handler
		will be invoked once for each of those touches.

		If a touchXXXHandler is set for a given event, events are never passed along to the
		parent layer (if you need dynamic bubbling behavior, use touchesXXXHandlers). */
	public typealias TouchHandler = TouchSequence<UITouchID> -> Void

	/** A dictionary whose keys are touch sequence IDs and whose values are touch sequences.
		This dictionary contains a value for each touch currently active on this layer.

		When a touch or touches handler is running, this property will already have been
		updated to a value incorporating the new touch event. */
	public var activeTouchSequences: [UITouchID: TouchSequence<UITouchID>] {
		return imageView?.activeTouchSequences ?? [UITouchID: UITouchSequence]()
	}

	/** A handler for when new touches arrive. See the TouchesHandler documentation for more
		details. */
	public var touchesBeganHandler: TouchesHandler? {
		get { return imageView?.touchesBeganHandler }
		set { imageView?.touchesBeganHandler = newValue }
	}

	/** A handler for when a new touch arrives. See the TouchHandler documentation for more
		details. */
	public var touchBeganHandler: TouchHandler? {
		get { return imageView?.touchBeganHandler }
		set { imageView?.touchBeganHandler = newValue }
	}

	/** A handler for when touches move. See the TouchesHandler documentation for more
		details. */
	public var touchesMovedHandler: TouchesHandler? {
		get { return imageView?.touchesMovedHandler }
		set { imageView?.touchesMovedHandler = newValue }
	}

	/** A handler for when a touch moves. See the TouchHandler documentation for more details. */
	public var touchMovedHandler: TouchHandler? {
		get { return imageView?.touchMovedHandler }
		set { imageView?.touchMovedHandler = newValue }
	}

	/** A handler for when touches end. See the TouchesHandler documentation for more
		details. */
	public var touchesEndedHandler: TouchesHandler? {
		get { return imageView?.touchesEndedHandler }
		set { imageView?.touchesEndedHandler = newValue }
	}

	/** A handler for when a touch ends. See the TouchHandler documentation for more details. */
	public var touchEndedHandler: TouchHandler? {
		get { return imageView?.touchEndedHandler }
		set { imageView?.touchEndedHandler = newValue }
	}

	/** A handler for when touches are cancelled. This may happen because a gesture with
		cancelsTouchesInView set to true has recognized, because of palm rejection, or because
		a system event (like a system gesture) has cancelled the touch.

		See TouchesHandler documentation for more details. */
	public var touchesCancelledHandler: TouchesHandler? {
		get { return imageView?.touchesCancelledHandler }
		set { imageView?.touchesCancelledHandler = newValue }
	}

	/** A handler for when a touch is cancelled. This may happen because a gesture with
		cancelsTouchesInView set to true has recognized, because of palm rejection, or because
		a system event (like a system gesture) has cancelled the touch.

		See TouchesHandler documentation for more details. */
	public var touchCancelledHandler: TouchHandler? {
		get { return imageView?.touchCancelledHandler }
		set { imageView?.touchCancelledHandler = newValue }
	}

	/** Returns a list of descendent layers of the receiver (including self) which are actively
		being touched, or [] if none are. */
	public var touchedDescendents: [Layer] {
		var accumulator = [Layer]()
		if activeTouchSequences.count > 0 {
			accumulator.append(self)
		}
		for sublayer in sublayers {
			accumulator += sublayer.touchedDescendents
		}
		return accumulator
	}
	#endif // touch + gesture stuff
	
	// MARK: Mouse handling
	#if os(OSX)
	
	/** This type is used for handling mouse input events. */
	public typealias MouseHandler = InputEvent -> Void
	
	/** Called when the mouse button is clicked down. */
	public var mouseDownHandler: MouseHandler? {
		get { return imageView?.mouseDownHandler }
		set { imageView?.mouseDownHandler = newValue}
	}
	
	
	/** Called when the mouse buttin is dragged. */
	public var mouseDraggedHandler: MouseHandler? {
		get { return imageView?.mouseDraggedHandler }
		set { imageView?.mouseDraggedHandler = newValue}
	}
	
	
	/** Called when the mouse button is released. */
	public var mouseUpHandler: MouseHandler? {
		get { return imageView?.mouseUpHandler }
		set { imageView?.mouseUpHandler = newValue}
	}
	
	
	/** Called when the mouse enters the layer. */
	public var mouseEnteredHandler: MouseHandler? {
		get { return imageView?.mouseEnteredHandler }
		set { imageView?.mouseEnteredHandler = newValue}
	}
	
	
	/** Called when the mouse exits the layer. */
	public var mouseExitedHandler: MouseHandler? {
		get { return imageView?.mouseExitedHandler }
		set { imageView?.mouseExitedHandler = newValue}
	}
	
	
	
	/** Called when the mouse moves at all on the layer. See also mouseDraggedHandler. */
	public var mouseMovedHandler: MouseHandler? {
		get { return imageView?.mouseMovedHandler }
		set { imageView?.mouseMovedHandler = newValue}
	}
	
	
	#endif

	// MARK: Convenience utilities

	public private(set) var willBeRemovedSoon: Bool = false
	public func removeAfterDuration(duration: NSTimeInterval) {
		willBeRemovedSoon = true
		afterDuration(duration) {
			self.parent = nil
		}
	}

	
	public func fadeOutAndRemoveAfterDuration(duration: NSTimeInterval) {
		willBeRemovedSoon = true
		Layer.animateWithDuration(duration, animations: {
			self.alpha = 0
			}, completionHandler: {
				self.parent = nil
		})
	}

	// MARK: - Internal interfaces

	private func _shouldMaskToBounds() -> Bool {
		if image != nil {
			if (self.shadow.alpha > 0 && self.cornerRadius > 0) {
				var prefix: String = "layers"
				if let offendingLayer = self.name {
					prefix = "your layer '\(offendingLayer)'"
				}
				// in this case unless you have a complex hierarchy,
				// you should probably use a rounded image.
				Environment.currentEnvironment?.exceptionHandler("\(prefix) can't have images, shadows and corner radii set all at the same time. 😣")
			}

			// don't set masksToBounds unless you have an image and a corner radius
			if (self.cornerRadius > 0) {
				return true
			}
		}

		// if you have a shadow set but no image, don't clip so you can see the shadow
		if (self.shadow.alpha > 0) {
			return false
		}

		// otherwise, always clip (making sublayers easier to crop/etc by default)
		return true
	}

	// MARK: - Internal interfaces

	private func parentDidChange() {
		parentView = parent?.view
		parent?.sublayers.append(self)
	}

	private func imageDidChange() {
		if let image = image {
			imageView?.image = image.systemImage
			size = image.size
			layer.masksToBounds = self._shouldMaskToBounds()
		}
	}

	private init(wrappingView: SystemView, name: String? = nil) {
		view = wrappingView
		self.name = name
	}
    
    
	/** Creates a new layer hosted by the given view. The layer wraps its own view, which is sized to the full dimensions of the hosting view. */
    convenience init(hostingView: SystemView, name: String? = nil) {
        self.init()
        self.parentView = hostingView
		self.frame = Rect(hostingView.bounds)
		#if os(iOS)
			self.view.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
		#else
			self.view.autoresizingMask = NSAutoresizingMaskOptions.ViewWidthSizable | NSAutoresizingMaskOptions.ViewHeightSizable
			
		#endif
    }

	// MARK: UIKit mapping

	var view: SystemView
	private var layer: CALayer {
		#if os(iOS)
		return view.layer
		#else
		return view.layer!
		#endif
	}
	private var imageView: TouchForwardingImageView? { return view as? TouchForwardingImageView }

	private var parentView: SystemView? {
		get { return view.superview }
		set { newValue?.addSubview(view) }
	}

	// MARK: Touch handling implementation

	class TouchForwardingImageView: SystemImageView {
		required init?(coder aDecoder: NSCoder) {
			fatalError("This method intentionally not implemented.")
		}

		override init(frame: CGRect) {
			super.init(frame: frame)
			#if os(OSX)
				self.wantsLayer = true
				
				// TODO(jb): Can probably lazily add this when a mouse Entered/moved/exited event happens, so not all layers need to have tracking areas by default.
				let options = NSTrackingAreaOptions.MouseEnteredAndExited | NSTrackingAreaOptions.MouseMoved | NSTrackingAreaOptions.ActiveInActiveApp | NSTrackingAreaOptions.InVisibleRect
				let trackingArea = NSTrackingArea(rect: self.visibleRect, options: options, owner: self, userInfo: nil)
				self.addTrackingArea(trackingArea)
			#endif
		}

		convenience init() {
			self.init(frame: CGRect())
		}
		
		#if os(iOS)
		override func pointInside(point: CGPoint, withEvent event: UIEvent?) -> Bool {
			// Try to hit test the presentation layer instead of the model layer.
			if let presentationLayer = layer.presentationLayer() as? CALayer {
				let screenPoint = layer.convertPoint(point, toLayer: nil)
				let presentationLayerPoint = presentationLayer.convertPoint(screenPoint, fromLayer: nil)
				return super.pointInside(presentationLayerPoint, withEvent: event)
			} else {
				return super.pointInside(point, withEvent: event)
			}
		}

		private typealias TouchSequenceMapping = [UITouchID: UITouchSequence]
		private var activeTouchSequences = TouchSequenceMapping()

		private func handleTouches(touches: NSSet, event: UIEvent?, touchesHandler: TouchesHandler?, touchHandler: TouchHandler?, touchSequenceMappingMergeFunction: (TouchSequenceMapping, TouchSequenceMapping) -> TouchSequenceMapping) -> Bool {
			precondition(touchesHandler == nil || touchHandler == nil, "Can't set both a touches*Handler and a touch*Handler")

			let newSequenceMappings = incorporateTouches(touches, intoTouchSequenceMappings: activeTouchSequences)

			activeTouchSequences = touchSequenceMappingMergeFunction(activeTouchSequences, newSequenceMappings)

			if let touchHandler = touchHandler {
				for (_, touchSequence) in newSequenceMappings {
					touchHandler(touchSequence)
				}
				return true
			} else if let touchesHandler = touchesHandler {
				return touchesHandler(newSequenceMappings)
			} else {
				return false
			}
		}

		var touchesBeganHandler: TouchesHandler?
		var touchBeganHandler: TouchHandler?
		override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) -> Void {
			if !handleTouches(touches, event: event, touchesHandler: touchesBeganHandler, touchHandler: touchBeganHandler, touchSequenceMappingMergeFunction: +) {
				super.touchesBegan(touches, withEvent: event)
			}
		}

		var touchesMovedHandler: TouchesHandler?
		var touchMovedHandler: TouchHandler?
		override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
			if !handleTouches(touches, event: event, touchesHandler: touchesMovedHandler, touchHandler: touchMovedHandler, touchSequenceMappingMergeFunction: +) {
				super.touchesMoved(touches, withEvent: event)
			}
		}

		var touchesEndedHandler: TouchesHandler?
		var touchEndedHandler: TouchHandler?
		override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
			if !handleTouches(touches, event: event, touchesHandler: touchesEndedHandler, touchHandler: touchEndedHandler, touchSequenceMappingMergeFunction: -) {
				super.touchesEnded(touches, withEvent: event)
			}
		}

		var touchesCancelledHandler: TouchesHandler?
		var touchCancelledHandler: TouchHandler?
		override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
			if !handleTouches(touches!, event: event, touchesHandler: touchesCancelledHandler, touchHandler: touchCancelledHandler, touchSequenceMappingMergeFunction: -) {
				super.touchesCancelled(touches, withEvent: event)
			}
		}
		#else
		
		// We want the coordinates to be flipped so they're the same as on iOS.
		override var flipped: Bool {
			return true
		}
		
		var mouseDownHandler: MouseHandler?
		override func mouseDown(event: NSEvent) {
			mouseDownHandler?(InputEvent(event: event))
		}
		
		
		var mouseMovedHandler: MouseHandler?
		override func mouseMoved(event: NSEvent) {
			mouseMovedHandler?(InputEvent(event: event))
		}
		
		
		var mouseUpHandler: MouseHandler?
		override func mouseUp(event: NSEvent) {
			mouseUpHandler?(InputEvent(event: event))
		}

		var mouseDraggedHandler: MouseHandler?
		override func mouseDragged(event: NSEvent) {
			mouseDraggedHandler?(InputEvent(event: event))
		}
		var mouseEnteredHandler: MouseHandler?
		override func mouseEntered(event: NSEvent) {
			mouseEnteredHandler?(InputEvent(event: event))
		}
		var mouseExitedHandler: MouseHandler?
		override func mouseExited(event: NSEvent) {
			mouseExitedHandler?(InputEvent(event: event))
		}
		#endif
	}

	// MARK: CALayerWrappingView

	class CALayerWrappingView: SystemView {
		let wrappedLayer: CALayer
		init(wrappedLayer: CALayer) {
			self.wrappedLayer = wrappedLayer

			super.init(frame: wrappedLayer.frame)

			#if os(iOS)
				layer.addSublayer(wrappedLayer)
			#else
				layer!.addSublayer(wrappedLayer)
			#endif
			setNeedsLayout()
		}

		required init?(coder aDecoder: NSCoder) {
			fatalError("init(coder:) has intentionally not been implemented")
		}

		override func layoutSubviews() {
			wrappedLayer.frame = bounds
		}
	}
    

    public var behaviors: [BehaviorType] = [] {
        didSet {
            Environment.currentEnvironment?.behaviorDriver.updateWithLayer(self, behaviors: behaviors)
        }
    }
}

extension Layer: Hashable {
	public var hashValue: Int {
		return view.hashValue
	}
}

extension Layer: CustomStringConvertible {
	public var description: String {
		var output = ""
		if let name = name {
			output += "\(name): "
		}
		output += view.description
		return output
	}
}

public func ==(a: Layer, b: Layer) -> Bool {
	return a === b
}


#if os(iOS)
private typealias UITouchSequence = TouchSequence<UITouchID>

private func touchSequencesFromTouchSet(touches: NSSet) -> [UITouchSequence] {
	return touches.map {
		let touch = $0 as! UITouch
		return TouchSequence(samples: [TouchSample(touch)], id: UITouchID(touch))
	}
}

private func touchSequenceMappingsFromTouchSequences<ID>(touchSequences: [TouchSequence<ID>]) -> [ID: TouchSequence<ID>] {
	return dictionaryFromElements(touchSequences.map { ($0.id, $0) })
}

private func incorporateTouchSequences<ID>(sequences: [TouchSequence<ID>], intoTouchSequenceMappings mappings: [ID: TouchSequence<ID>]) -> [TouchSequence<ID>] {
	return sequences.map { (mappings[$0.id] ?? TouchSequence(samples: [], id: $0.id)) + $0 }
}

private func incorporateTouches(touches: NSSet, intoTouchSequenceMappings mappings: [UITouchID: TouchSequence<UITouchID>]) -> [UITouchID: TouchSequence<UITouchID>] {
	let updatedTouchSequences = incorporateTouchSequences(touchSequencesFromTouchSet(touches), intoTouchSequenceMappings: mappings)
	return touchSequenceMappingsFromTouchSequences(updatedTouchSequences)
}

#endif


#if os(iOS)
	import UIKit
	public typealias SystemImageView = UIImageView
	#else
	import AppKit
	public typealias SystemImageView = NSImageView
	
	extension SystemView {
		func setNeedsLayout() {
			// TODO(jb): What's the OS X equiv of this again?
			// no-op?
		}
		
		func layoutSubviews() {
			self.resizeSubviewsWithOldSize(self.frame.size)
		}
		
		var backgroundColor: SystemColor? {
			get { 
				if let color = self.layer?.backgroundColor {
					return SystemColor(CGColor: color)
				}
				return nil
			}
			set {
				if let systemColor = newValue {
					self.layer?.backgroundColor = systemColor.CGColor
				} else {
					self.layer?.backgroundColor = nil
				}
			}
		}
		
		
		var alpha: CGFloat {
			get { return CGFloat(self.layer!.opacity) }
			set { self.layer?.opacity = Float(self.alpha) }
		}
	}
#endif
