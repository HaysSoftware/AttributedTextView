//
//  SwiftyLabel.swift
//
//  Created by Edwin Vermeer on 25/11/2016.
//  Copyright © 2016 Edwin Vermeer. All rights reserved.
//

import UIKit

/**
 Set this class as the 'Custom Class' when you add a UITextView in the interfacebuilder. 
 Use the attributer property for setting the attributed text.

 You can create your own textview class and use this class as it's base class. override the configureAttributedLabel function and set the self.attributer to your prefered styling. For instance self.attributer = self.text?.myHeader See the samples for how you could add your own custom property for interface builder and alsu use that.
 */
@IBDesignable open class AttributedTextView: UITextView, UITextViewDelegate {
    //MARK: - Private Variables
    private var _needsUpdateTrim = false
    private var _originalMaximumNumberOfLines: Int = 0
    private var _originalAttributedText: NSAttributedString!
    private var _originalTextLength: Int {
        get {
            return _originalAttributedText?.length ?? 0
        }
    }
    private var intrinsicContentHeight: CGFloat {
        return intrinsicContentSize.height
    }
    private var cachedIntrinsicContentHeight: CGFloat?

    //MARK: - Public Variables
    
    /**
     The maximum number of lines that the text view can display. If text does not fit that number it will be trimmed.
     Default is `0` which means that no text will be never trimmed.
     */
    @IBInspectable
    public var maximumNumberOfLines: Int = 0 {
        didSet {
            _originalMaximumNumberOfLines = maximumNumberOfLines
            setNeedsLayout()
        }
    }
    
    /**The text to trim the original text. Setting this property resets `attributedReadMoreText`.*/
    @IBInspectable
    public var readMoreText: String? {
        get {
            return attributedReadMoreText?.string
        }
        set {
            if let text = newValue {
                attributedReadMoreText = attributedStringWithDefaultAttributes(from: text)
            } else {
                attributedReadMoreText = nil
            }
        }
    }
    
    /**The attributed text to trim the original text. Setting this property resets `readMoreText`.*/
    public var attributedReadMoreText: NSAttributedString? {
        didSet {
            setNeedsLayout()
        }
    }
    
    /**
     The text to append to the original text when not trimming.
     */
    @IBInspectable
    public var readLessText: String? {
        get {
            return attributedReadLessText?.string
        }
        set {
            if let text = newValue {
                attributedReadLessText = attributedStringWithDefaultAttributes(from: text)
            } else {
                attributedReadLessText = nil
            }
        }
    }
    
    /**
     The attributed text to append to the original text when not trimming.
     */
    public var attributedReadLessText: NSAttributedString? {
        didSet {
            setNeedsLayout()
        }
    }
    
    /**
     A Boolean that controls whether the text view should trim it's content to fit the `maximumNumberOfLines`.
     The default value is `false`.
     */
    @IBInspectable
    public var shouldTrim: Bool = false {
        didSet {
            guard shouldTrim != oldValue else { return }
            
            if shouldTrim {
                maximumNumberOfLines = _originalMaximumNumberOfLines
            } else {
                let _maximumNumberOfLines = maximumNumberOfLines
                maximumNumberOfLines = 0
                _originalMaximumNumberOfLines = _maximumNumberOfLines
            }
            cachedIntrinsicContentHeight = nil
            setNeedsLayout()
        }
    }

    
    //MARK: - Initializers
    // required when using @IBDesignable
    override public init(frame: CGRect, textContainer: NSTextContainer?) {
        readMoreTextPadding = .zero
        readLessTextPadding = .zero

        super.init(frame: frame, textContainer: textContainer)
        super.delegate = self
        setupDefaults()
    }
    
    public convenience init(frame: CGRect) {
        self.init(frame: frame, textContainer: nil)
    }
    
    public convenience init() {
        self.init(frame: CGRect.zero, textContainer: nil)
    }
    
    // required when using @IBDesignable
    required public init?(coder aDecoder: NSCoder) {
        readMoreTextPadding = .zero
        readLessTextPadding = .zero
        super.init(coder: aDecoder)
        super.delegate = self
        setupDefaults()
    }
    
    //MARK: - Overrides
    // Make sure configureAttributedTextView is called right after activation from the storyboard.
    open override func awakeFromNib() {
        super.awakeFromNib()
        configureAttributedTextView()
    }
    
    // Make sure configureAttributedTextView is called inside interfacebuilder
    open override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        configureAttributedTextView()
    }
    
    open override var attributedText: NSAttributedString! {
        willSet {
            if #available(iOS 9.0, *) { return }
            //on iOS 8 text view should be selectable to properly set attributed text
            if newValue != nil {
                isSelectable = true
            }
        }
        didSet {
            _originalAttributedText = attributedText
        }
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        
        if _needsUpdateTrim {
            //reset text to force update trim
            attributedText = _originalAttributedText
            _needsUpdateTrim = false
        }
        needsTrim() ? showLessText() : showMoreText()
    }
    
    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return hitTest(pointInGliphRange: point, event: event) { _ in
            guard pointIsInReadMoreOrReadLessTextRange(point: point) != nil else { return nil }
            return self
        }
    }
    
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let point = touches.first?.location(in: self) {
            shouldTrim = pointIsInReadMoreOrReadLessTextRange(point: point) ?? shouldTrim
        }
        super.touchesEnded(touches, with: event)
    }

    // just an override for triggering configureAttributedTextView
    override open var text: String! {
        didSet {
            configureAttributedTextView()
            if let text = text {
                _originalAttributedText = attributedStringWithDefaultAttributes(from: text)
            } else {
                _originalAttributedText = nil
            }
        }
    }
    
    // Return the contentSize if its forced enabled
    override open var intrinsicContentSize: CGSize {
        textContainer.size = CGSize(width: bounds.size.width, height: CGFloat.greatestFiniteMagnitude)
        var intrinsicContentSize = layoutManager.boundingRect(forGlyphRange: layoutManager.glyphRange(for: textContainer), in: textContainer).size
        intrinsicContentSize.width = UIView.noIntrinsicMetric
        intrinsicContentSize.height += (textContainerInset.top + textContainerInset.bottom)
        intrinsicContentSize.height = ceil(intrinsicContentSize.height)
        
        return self.forceIntrinsicContentSizeToBeContentSize ? self.contentSize : intrinsicContentSize
    }

    /**
     Delegate that can be set for forwarding events from the UITextView
     */
    override open var delegate: UITextViewDelegate? {
        get {
            return super.delegate
        }
        set {
            _delegate = newValue
        }
    }

    //MARK: - Public Functions
    
    /**Block to be invoked when text view changes its content size.*/
    public var onSizeChange: (AttributedTextView)->() = { _ in }
    
    /**
     Force to update trimming on the next layout pass. To update right away call `layoutIfNeeded` right after.
     */
    public func setNeedsUpdateTrim() {
        _needsUpdateTrim = true
        setNeedsLayout()
    }
    

    //MARK: - Private Functions
    private func setupDefaults() {
        isScrollEnabled = false
        isEditable = false
        
        let defaultReadMoreText = "... " + NSLocalizedString("AttributedTextView.readMore", value: "more", comment: "")
        
        let attributedReadMoreText = NSAttributedString(string: defaultReadMoreText, attributes: [
            NSAttributedString.Key.foregroundColor: UIColor.lightGray,
            NSAttributedString.Key.font: font ?? UIFont.systemFont(ofSize: 14)
            ])
        self.attributedReadMoreText = attributedReadMoreText
    }

    private func attributedStringWithDefaultAttributes(from text: String) -> NSAttributedString {
        return NSAttributedString(string: text, attributes: [
            NSAttributedString.Key.font: font ?? UIFont.systemFont(ofSize: 14),
            NSAttributedString.Key.foregroundColor: tintColor ?? textColor ?? UIColor.black
            ])
    }
    
    private func needsTrim() -> Bool {
        return shouldTrim && readMoreText != nil
    }
    
    private func showLessText() {
        if let readMoreText = readMoreText, text.hasSuffix(readMoreText) { return }
        
        shouldTrim = true
        textContainer.maximumNumberOfLines = maximumNumberOfLines
        
        layoutManager.invalidateLayout(forCharacterRange: layoutManager.characterRangeThatFits(textContainer: textContainer), actualCharacterRange: nil)
        textContainer.size = CGSize(width: bounds.size.width, height: CGFloat.greatestFiniteMagnitude)
        
        if let text = attributedReadMoreText {
            let range = rangeToReplaceWithReadMoreText()
            guard range.location != NSNotFound else { return }
            
            textStorage.replaceCharacters(in: range, with: text)
        }
        
        invalidateIntrinsicContentSize()
        invokeOnSizeChangeIfNeeded()
    }
    
    private func showMoreText() {
        if let readLessText = readLessText, text.hasSuffix(readLessText) { return }
        
        shouldTrim = false
        textContainer.maximumNumberOfLines = 0
        
        if let originalAttributedText = _originalAttributedText?.mutableCopy() as? NSMutableAttributedString {
            attributedText = _originalAttributedText
            let range = NSRange(location: 0, length: text.unicodeScalars.count)
            if let attributedReadLessText = attributedReadLessText {
                originalAttributedText.append(attributedReadLessText)
            }
            textStorage.replaceCharacters(in: range, with: originalAttributedText)
        }
        
        invalidateIntrinsicContentSize()
        invokeOnSizeChangeIfNeeded()
    }
    
    private func invokeOnSizeChangeIfNeeded() {
        if let cachedIntrinsicContentHeight = cachedIntrinsicContentHeight {
            if intrinsicContentHeight != cachedIntrinsicContentHeight {
                self.cachedIntrinsicContentHeight = intrinsicContentHeight
                onSizeChange(self)
            }
        } else {
            self.cachedIntrinsicContentHeight = intrinsicContentHeight
            onSizeChange(self)
        }
    }
    
    private func rangeToReplaceWithReadMoreText() -> NSRange {
        let rangeThatFitsContainer = layoutManager.characterRangeThatFits(textContainer: textContainer)
        if NSMaxRange(rangeThatFitsContainer) == _originalTextLength {
            return NSMakeRange(NSNotFound, 0)
        }
        else {
            let lastCharacterIndex = characterIndexBeforeTrim(range: rangeThatFitsContainer)
            if lastCharacterIndex > 0 {
                return NSMakeRange(lastCharacterIndex, textStorage.length - lastCharacterIndex)
            }
            else {
                return NSMakeRange(NSNotFound, 0)
            }
        }
    }
    
    private func characterIndexBeforeTrim(range rangeThatFits: NSRange) -> Int {
        if let text = attributedReadMoreText {
            let readMoreBoundingRect = attributedReadMoreText(text: text, boundingRectThatFits: textContainer.size)
            let lastCharacterRect = layoutManager.boundingRectForCharacterRange(range: NSMakeRange(NSMaxRange(rangeThatFits)-1, 1), inTextContainer: textContainer)
            var point = lastCharacterRect.origin
            point.x = textContainer.size.width - ceil(readMoreBoundingRect.size.width)
            let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer, fractionOfDistanceThroughGlyph: nil)
            let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            return characterIndex - 1
        } else {
            return NSMaxRange(rangeThatFits) - readMoreText!.length
        }
    }
    
    private func attributedReadMoreText(text aText: NSAttributedString, boundingRectThatFits size: CGSize) -> CGRect {
        let textContainer = NSTextContainer(size: size)
        let textStorage = NSTextStorage(attributedString: aText)
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        let readMoreBoundingRect = layoutManager.boundingRectForCharacterRange(range: NSMakeRange(0, text.length), inTextContainer: textContainer)
        return readMoreBoundingRect
    }
    
    private func readMoreTextRange() -> NSRange {
        var readMoreTextRange = rangeToReplaceWithReadMoreText()
        if readMoreTextRange.location != NSNotFound {
            readMoreTextRange.length = readMoreText!.length + 1
        }
        return readMoreTextRange
    }
    
    private func readLessTextRange() -> NSRange {
        return NSRange(location: _originalTextLength, length: readLessText!.length + 1)
    }
    
    private func pointIsInReadMoreOrReadLessTextRange(point aPoint: CGPoint) -> Bool? {
        if needsTrim() && pointIsInTextRange(point: aPoint, range: readMoreTextRange(), padding: readMoreTextPadding) {
            return false
        } else if readLessText != nil && pointIsInTextRange(point: aPoint, range: readLessTextRange(), padding: readLessTextPadding) {
            return true
        }
        return nil
    }

    
    /**
     A padding around "read more" text to adjust touchable area.
     If text is trimmed touching in this area will change `shouldTream` to `false` and remove trimming.
     That will cause text view to change it's content size. Use `onSizeChange` to adjust layout on that event.
     */
    public var readMoreTextPadding: UIEdgeInsets = .zero
    
    /**
     A padding around "read less" text to adjust touchable area.
     If text is not trimmed and `readLessText` or `attributedReadLessText` is set touching in this area
     will change `shouldTream` to `true` and cause trimming. That will cause text view to change it's content size.
     Use `onSizeChange` to adjust layout on that event.
     */
    public var readLessTextPadding: UIEdgeInsets = .zero
    
    // For enabeling the size adjustment
    @IBInspectable open var forceIntrinsicContentSizeToBeContentSize: Bool = false {
        didSet { configureAttributedTextView() }
    }

    // Subclass AttributedTextView and override this function if you want to use easy custum controls in interface builder
    open func configureAttributedTextView() {
    }
    
    // storage variable for the Attributer
    private var _attributer: Attributer?

    /**
     The attributer object that will set the attributedText
     */
    open var attributer: Attributer {
        get {
            if _attributer == nil {
                _attributer = Attributer("")
            }
            return _attributer!
        }
        set { 
            _attributer = newValue
            self.attributedText = _attributer?.attributedText

            if _attributer?.hasCallbacks() ?? false {
                // Without these makeInteract does not work
                self.isUserInteractionEnabled = true
                self.isSelectable = true
                self.isEditable = false
            }
            if let color = _attributer?.linkColor {
                self.linkTextAttributes = [NSAttributedString.Key.foregroundColor: color as Any]
            }
        }
    }

    /**
     If you manually set the delegate on the AttributedTextView, then it will set this property instead of the actual delegate. The actual delegate will be set to this class itself for handling the interactions on the links. events will be forwarded to the _delegate.
     */
    public var _delegate: UITextViewDelegate?
    
    
    // MARK: - UITextViewDelegate functions - forwarding all to _delegate

    /**
     UITextViewDelegate function for forwarding the textViewShoudlBeginEditing
     
     -property textView: The UITextView where the delegate is called on
     */
    public func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        return _delegate?.textViewShouldBeginEditing?(textView) ?? false
    }
    
    /**
     UITextViewDelegate function for forwarding the textViewShouldEndEditing
     
     -property textView: The UITextView where the delegate is called on
     */
    public func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        return _delegate?.textViewShouldEndEditing?(textView) ?? false
    }
    
    /**
     UITextViewDelegate function for forwarding the textViewDidBeginEditing
     
     -property textView: The UITextView where the delegate is called on
     */
    public func textViewDidBeginEditing(_ textView: UITextView) {
        _delegate?.textViewDidBeginEditing?(textView)
    }
    
    /**
     UITextViewDelegate function for forwarding the textViewDidEndEditing
     
     -property textView: The UITextView where the delegate is called on
     */
    public func textViewDidEndEditing(_ textView: UITextView) {
        _delegate?.textViewDidEndEditing?(textView)
    }
    
    
    /**
     UITextViewDelegate function for forwarding the shouldChangeTextIn range
     
     -property textView: The UITextView where the delegate is called on
     -property shouldChangeTextIn: the range
     -property replacementText: the replacement text
     */
    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        return _delegate?.textView?(textView, shouldChangeTextIn: range, replacementText: text) ?? false
    }
    
    /**
     UITextViewDelegate function for forwarding the textViewDidChange
     
     -property textView: The UITextView where the delegate is called on
     */
    public func textViewDidChange(_ textView: UITextView) {
        _delegate?.textViewDidChange?(textView)
    }
    
    /**
     UITextViewDelegate function for forwarding the textViewDidChangeSelection
     
     -property textView: The UITextView where the delegate is called on
     */
    public func textViewDidChangeSelection(_ textView: UITextView) {
        _delegate?.textViewDidChangeSelection?(textView)
    }
    
    /**
     UITextViewDelegate function for forwarding the shouldInteractWith URL
     
     -property textView: The UITextView where the delegate is called on
     -property shouldInteractWith: The URL to interact with
     -property characterRagne: the NSRange for the selection
     -property interaction: The UITextItemInteraction
     */
    @available(iOS 10.0, *)
    public func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        _attributer?.interactWithURL(URL: URL)
        return _delegate?.textView?(textView, shouldInteractWith: URL, in: characterRange, interaction: interaction) ?? false
    }
    
    /**
     UITextViewDelegate function for forwarding the shouldInteractWith textAttachment
     
     -property textView: The UITextView where the delegate is called on
     -property shouldInteractWith: the NSTextAttachement
     -property characterRange: the NSRange for the selection
     -property interaction: The UITextItemInteraction
     */
    @available(iOS 10.0, *)
    public func textView(_ textView: UITextView, shouldInteractWith textAttachment: NSTextAttachment, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        return _delegate?.textView?(textView, shouldInteractWith: textAttachment, in: characterRange, interaction: interaction) ?? false
    }
    
    /**
     UITextViewDelegate function for forwarding the shouldInteractWith URL
     
     -property textView: The UITextView where the delegate is called on
     -property shouldInteractWith: the NSTextAttachement
     -property characterRange: the NSRange for the selection
     */
    @available(iOS, introduced: 7.0, deprecated: 10.0, message: "Use textView:shouldInteractWithURL:inRange:forInteractionType: instead")
    public func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        _attributer?.interactWithURL(URL: URL)
        return _delegate?.textView!(textView, shouldInteractWith: URL, in: characterRange) ?? false
    }
    
    /**
     UITextViewDelegate function for forwarding the shouldInteractWith textAttachment
     
     -property textView: The UITextView where the delegate is called on
     -property shouldInteractWith: the NSTextAttachement
     -property characterRange: the NSRange for the selection
     */
    @available(iOS, introduced: 7.0, deprecated: 10.0, message: "Use textView:shouldInteractWithTextAttachment:inRange:forInteractionType: instead")
    public func textView(_ textView: UITextView, shouldInteractWith textAttachment: NSTextAttachment, in characterRange: NSRange) -> Bool {
        return _delegate?.textView?(textView, shouldInteractWith: textAttachment, in: characterRange) ?? false
    }
}

extension String {
    var length: Int {
        return utf16.count
    }
}

extension UITextView {
    
    /**
     Calls provided `test` block if point is in gliph range and there is no link detected at this point.
     Will pass in to `test` a character index that corresponds to `point`.
     Return `self` in `test` if text view should intercept the touch event or `nil` otherwise.
     */
    public func hitTest(pointInGliphRange aPoint: CGPoint, event: UIEvent?, test: (Int) -> UIView?) -> UIView? {
        guard let charIndex = charIndexForPointInGlyphRect(point: aPoint) else {
            return super.hitTest(aPoint, with: event)
        }
        guard textStorage.attribute(NSAttributedString.Key.link, at: charIndex, effectiveRange: nil) == nil else {
            return super.hitTest(aPoint, with: event)
        }
        return test(charIndex)
    }
    
    /**
     Returns true if point is in text bounding rect adjusted with padding.
     Bounding rect will be enlarged with positive padding values and decreased with negative values.
     */
    public func pointIsInTextRange(point aPoint: CGPoint, range: NSRange, padding: UIEdgeInsets) -> Bool {
        var boundingRect = layoutManager.boundingRectForCharacterRange(range: range, inTextContainer: textContainer)
        boundingRect = boundingRect.offsetBy(dx: textContainerInset.left, dy: textContainerInset.top)
        boundingRect = boundingRect.insetBy(dx: -(padding.left + padding.right), dy: -(padding.top + padding.bottom))
        return boundingRect.contains(aPoint)
    }
    
    /**
     Returns index of character for glyph at provided point. Returns `nil` if point is out of any glyph.
     */
    public func charIndexForPointInGlyphRect(point aPoint: CGPoint) -> Int? {
        let point = CGPoint(x: aPoint.x, y: aPoint.y - textContainerInset.top)
        let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer)
        let glyphRect = layoutManager.boundingRect(forGlyphRange: NSMakeRange(glyphIndex, 1), in: textContainer)
        if glyphRect.contains(point) {
            return layoutManager.characterIndexForGlyph(at: glyphIndex)
        } else {
            return nil
        }
    }
    
}

extension NSLayoutManager {
    
    /**
     Returns characters range that completely fits into container.
     */
    public func characterRangeThatFits(textContainer container: NSTextContainer) -> NSRange {
        var rangeThatFits = self.glyphRange(for: container)
        rangeThatFits = self.characterRange(forGlyphRange: rangeThatFits, actualGlyphRange: nil)
        return rangeThatFits
    }
    
    /**
     Returns bounding rect in provided container for characters in provided range.
     */
    public func boundingRectForCharacterRange(range aRange: NSRange, inTextContainer container: NSTextContainer) -> CGRect {
        let glyphRange = self.glyphRange(forCharacterRange: aRange, actualCharacterRange: nil)
        let boundingRect = self.boundingRect(forGlyphRange: glyphRange, in: container)
        return boundingRect
    }
    
}

