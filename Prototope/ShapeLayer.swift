//
//  ShapeLayer.swift
//  Prototope
//
//  Created by Jason Brennan on Mar-27-2015.
//  Copyright (c) 2015 Khan Academy. All rights reserved.
//

import UIKit


/** This layer represents a 2D shape, which is drawn from a supplied `Path` object. */
public class ShapeLayer: Layer {
	
	
	/** Creates a circle with the given center and radius. */
	convenience public init(circleCenter: Point, radius: Double, parent: Layer? = nil, name: String? = nil) {
		self.init(ovalInRectangle: Rect(x: 0, y: 0, width: radius, height: radius), parent: parent, name: name)
	}
	
	
	/** Creates an oval within the given rectangle. */
	convenience public init(ovalInRectangle: Rect, parent: Layer? = nil, name: String? = nil) {		
		self.init(segments: Segment.segmentsForOvalInRect(ovalInRectangle), closed: true, parent: parent, name: name)
	}
	
	
	/** Creates a rectangle with an optional corner radius. */
	convenience public init(rectangle: Rect, cornerRadius: Double = 0, parent: Layer? = nil, name: String? = nil) {
		self.init(segments: [Segment](), closed: true, parent: parent, name: name)
	}
	
	
	/** Creates a line from two points. */
	convenience public init(lineFromFirstPoint firstPoint: Point, toSecondPoint secondPoint: Point, parent: Layer? = nil, name: String? = nil) {
		self.init(segments: [Segment](), parent: parent, name: name)
	}
	
	
	/** Creates a regular polygon path with the given number of sides. */
	convenience public init(polygonWithNumberOfSides: Int, parent: Layer? = nil, name: String? = nil) {
		self.init(segments: [Segment](), closed: true, parent: parent, name: name)
	}
	
	
	/** Initialize the ShapeLayer with a given path. */
	public init(segments: [Segment], closed: Bool = false, parent: Layer? = nil, name: String? = nil) {
		
		self.segments = segments
		self.closed = closed
		
		super.init(parent: parent, name: name, viewClass: ShapeView.self)
		
		self.shapeViewLayer.path = self.bezierPath.CGPath
		self.shapeViewLayer.strokeColor = Color.black.CGColor
		self.shapeViewLayer.fillColor = nil
	}
	
	
	
	
	// MARK: - Properties
	
	// TODO(jb): These aren't actually setting properly on the shapeLayer on init(). Fixit!
	/** The fill colour for the shape. Defaults to `Color.black`. This is distinct from the layer's background colour. */
	public var fillColor: Color? = Color.black {
		didSet {
			shapeViewLayerStyleChanged()
		}
	}
	
	
	/** The stroke colour for the shape. Defaults to `Color.black`. */
	public var strokeColor: Color? = Color.black {
		didSet {
			shapeViewLayerStyleChanged()
		}
	}
	
	
	/** The width of the stroke. Defaults to 1.0. */
	public var strokeWidth = 1.0 {
		didSet {
			shapeViewLayerStyleChanged()
		}
	}
	
	
	// MARK: - Segments
	
	/** A list of all segments of this path. */
	public var segments: [Segment]
	
	/** Gets the first segment of the path, if it exists. */
	public var firstSegment: Segment? {
		return segments.first
	}
	
	
	/** Gets the last segment of the path, if it exists. */
	public var lastSegment: Segment? {
		return segments.last
	}
	
	
	/** Convenience method to add a point by wrapping it in a segment. */
	public func addPoint(point: Point) {
		self.segments.append(Segment(point: point))
	}
	
	
	/** Replaces the segment at the given index. Throws an environment exception if the given index isn't in the segment list. */
	public func replaceSegmentAtIndex(index: Int, withSegment segment: Segment) {
		if index >= self.segments.count {
			Environment.currentEnvironment?.exceptionHandler("Tried to replace a path segment at index \(index) but there are only \(self.segments.count) elements")
			return
		}
		
		self.segments[index] = segment
		
	}
	
	
	/** If the path is closed, the first and last segments will be connected. */
	public var closed: Bool {
		didSet {
			self.shapeViewLayer.path = self.bezierPath.CGPath
		}
	}
	
	
	/** Update the shape layer to show a new path. */
//	public func updatePath(newPath: Path) {
//		self.path = newPath
//		self.shapeViewLayer.path = self.path.bezierPath.CGPath
//		self.bounds = self.path.bounds
//	}
	
	
	/** Represents the types of cap styles path segment endpoints will show. Only affects open paths. */
	public enum LineCapStyle {
		
		/** The line cap will have butts for ends. */
		case Butt
		
		/** The line cap will have round ends. */
		case Round
		
		/** The line cap will have square ends. */
		case Square
		
		internal func capStyleString() -> String {
			switch self {
			case Butt:
				return kCALineCapButt
			case Round:
				return kCALineCapRound
			case Square:
				return kCALineCapSquare
			}
		}
	}
	
	
	/** The line cap style for the path. Defaults to LineCapStyle.Butt. */
	public var lineCapStyle: LineCapStyle = .Butt {
		didSet {
			shapeViewLayerStyleChanged()
		}
	}
	
	
	/** Represents the types of join styles path segments will show at their joins. */
	public enum LineJoinStyle {
		
		/** Lines will be joined with a miter style. */
		case Miter
		
		/** Lines will be joined with a round style. */
		case Round
		
		/** Line joins will have beveled edges. */
		case Bevel
		
		internal func joinStyleString() -> String {
			switch self {
			case Miter:
				return kCALineJoinMiter
			case Round:
				return kCALineJoinRound
			case Bevel:
				return kCALineJoinBevel
			}
		}
	}
	
	
	/** The line join style for path lines. Defaults to LineJoinStyle.Miter. */
	public var lineJoinStyle: LineJoinStyle = .Miter {
		didSet {
			shapeViewLayerStyleChanged()
		}
	}
	
	
	// MARK: - Private details
	
	private var shapeViewLayer: CAShapeLayer {
		return self.view.layer as! CAShapeLayer
	}
	
	
	private class ShapeView: UIView {
		override class func layerClass() -> AnyClass {
			return CAShapeLayer.self
		}
	}
	
	
	private func shapeViewLayerStyleChanged() {
		var layer = self.shapeViewLayer
		layer.lineCap = self.lineCapStyle.capStyleString()
		layer.lineJoin = self.lineJoinStyle.joinStyleString()
		
		if let fillColor = fillColor {
			self.shapeViewLayer.fillColor = fillColor.CGColor
		} else {
			self.shapeViewLayer.fillColor = nil
		}
		
		
		if let strokeColor = strokeColor {
			self.shapeViewLayer.strokeColor = strokeColor.CGColor
		} else {
			self.shapeViewLayer.strokeColor = nil
		}
		
		self.shapeViewLayer.lineWidth = CGFloat(strokeWidth)
	}
	
	
	
	
	
	// MARK: - Geometry
	
	/** Returns the bounds of the path, in its own coordinate space. */
//	public var bounds: Rect {
//		return Rect(self.bezierPath.bounds)
//	}
	
	
	var bezierPath: UIBezierPath {
		// TODO(jb): Super naiive implementation. doesn't cache, doesn't handle "built in" shape paths, etc.
		let bezierPath = UIBezierPath()
		var isFirstSegment = true
		var currentPoint = Point()
		var previousPoint = Point()
		var currentHandleIn = Point()
		var currentHandleOut = Point()
		
		func drawSegment(segment: Segment) {
			currentPoint = segment.point
			
			if isFirstSegment {
				bezierPath.moveToPoint(CGPoint(currentPoint))
				isFirstSegment = false
			} else {
				if let segmentHandleIn = segment.handleIn {
					currentHandleIn = currentPoint + segmentHandleIn
				}
				
				if currentHandleIn == currentPoint && currentHandleOut == previousPoint {
					bezierPath.addLineToPoint(CGPoint(currentPoint))
				} else {
					println("p: \(currentPoint), cp1: \(currentHandleOut), cp2: \(currentHandleIn)")
					bezierPath.addCurveToPoint(CGPoint(currentPoint), controlPoint1: CGPoint(currentHandleOut), controlPoint2: CGPoint(currentHandleIn))
				}
			}
			
			previousPoint = currentPoint
			if let segmentHandleOut = segment.handleOut {
				currentHandleOut = previousPoint + segmentHandleOut
			}
			
		}
		for segment in self.segments {
			drawSegment(segment)
		}
		
		if self.closed && self.segments.count > 0 {
			drawSegment(self.segments[0])
			bezierPath.closePath()
		}
		bezierPath.applyTransform(CGAffineTransformMakeTranslation(250, 250))
		return bezierPath
	}
	
}

/** A segment represents a point on a path, and may optionally have control handles for a curve on either side. */
public struct Segment: Printable {
	
	/** The anchor point / location of this segment. */
	public let point: Point
	
	
	/** The control point going in to this segment, used when computing curves. */
	public let handleIn: Point?
	
	/** The control point coming out of this segment, used when computing curves. */
	public let handleOut: Point?
	
	
	/** Initialize a segment with the given point and optional handle points. */
	public init(point: Point, handleIn: Point? = nil, handleOut: Point? = nil) {
		self.point = point
		self.handleIn = handleIn
		self.handleOut = handleOut
	}
	
	public var description: String {
		return self.point.description
	}
}


/** Convenience functions for creating shapes. */
extension Segment {
	
	
	/** Creates a set of segments for drawing an oval in the given rect. Algorithm based on paper.js */
	static func segmentsForOvalInRect(rect: Rect) -> [Segment] {
		
		// Magic number for approximating ellipse control points.
		let kappa = 4.0 * (sqrt(2.0) - 1.0) / 3.0
		let kappaSegments = [
			Segment(point: Point(x: -1.0, y: 0.0), handleIn: Point(x: 0.0, y: kappa), handleOut: Point(x: 0.0, y: -kappa)),
			Segment(point: Point(x: 0.0, y: -1.0), handleIn: Point(x: -kappa, y: 0.0), handleOut: Point(x: kappa, y: 0.0)),
			Segment(point: Point(x: 1.0, y: 0.0), handleIn: Point(x: 0.0, y: -kappa), handleOut: Point(x: 0.0, y: kappa)),
			Segment(point: Point(x: 0.0, y: 1.0), handleIn: Point(x: kappa, y: 0.0), handleOut: Point(x: -kappa, y: 0.0))
		]
		
		var segments = [Segment]()
		let radius = Point(x: rect.size.width / 2.0, y: rect.size.height / 2.0)
		let center = rect.center
		
		for i in 0..<kappaSegments.count {
			let kappaSegment = kappaSegments[i]
			
			let point = kappaSegment.point * radius + center
			let handleIn = kappaSegment.handleIn! * radius
			let handleOut = kappaSegment.handleOut! * radius
			
			segments.append(Segment(point: point, handleIn: handleIn, handleOut: handleOut))
		}
		return segments
	}
}

