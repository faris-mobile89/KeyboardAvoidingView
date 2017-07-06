//
//  KeyboardAvoidingView.swift
//  Copyright (c) Anton Plebanovich.
//

import UIKit

//-----------------------------------------------------------------------------
// MARK: - Helper Extension
//-----------------------------------------------------------------------------

private extension UIView {
    var rootView: UIView {
        return superview?.rootView ?? self
    }
}

//-----------------------------------------------------------------------------
// MARK: - Class Implementation
//-----------------------------------------------------------------------------

/// Configures bottom constraint constant or frame height to avoid keyboard.
/// Bottom constraint should be added to Layout Guide or superview bottom.
public class KeyboardAvoidingView: UIView {
    
    //-----------------------------------------------------------------------------
    // MARK: - Public Properties
    //-----------------------------------------------------------------------------
    
    /// Disable/enable resize back when keyboard dismiss. Might be helpful for some animations.
    @IBInspectable public var restoreDefaultConstant: Bool = true
    
    /// Disable/enable animations. Could be used in case view isn't appeared yet to prevent broken animations for example.
    public var animate = true
    
    /// Disable reaction to keyboard notifications.
    public var disable = false
    
    //-----------------------------------------------------------------------------
    // MARK: - Private properties
    //-----------------------------------------------------------------------------
    
    private var bottomConstraint: NSLayoutConstraint?
    private var defaultConstant: CGFloat?
    private var layoutGuideHeight: CGFloat?
    private var defaultHeight: CGFloat?
    private var previousKeyboardFrame: CGRect?
    
    private var isConstraintsAligned: Bool {
        return bottomConstraint != nil
    }
    
    private var isInverseOrder: Bool? {
        guard let firstItem = bottomConstraint?.firstItem else { return nil }
        
        return firstItem === self
    }
    
    //-----------------------------------------------------------------------------
    // MARK: - Initialization, Setup and Configuration
    //-----------------------------------------------------------------------------
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        setup()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        setup()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setup() {
        NotificationCenter.default.addObserver(self, selector: #selector(KeyboardAvoidingView.keyboardWillChangeFrameNotification(_:)), name: .UIKeyboardWillChangeFrame, object: nil)
    }
    
    private func configure() {
        if bottomConstraint == nil, let newBottomConstraint = getBottomConstraint() {
            bottomConstraint = newBottomConstraint
            defaultConstant = newBottomConstraint.constant
            
            if let layoutGuide = bottomConstraint?.firstItem as? UILayoutSupport {
                layoutGuideHeight = layoutGuide.length
            } else if let layoutGuide = bottomConstraint?.secondItem as? UILayoutSupport {
                layoutGuideHeight = layoutGuide.length
            }
        } else if defaultHeight == nil {
            defaultHeight = frame.height
        }
    }
    
    //-----------------------------------------------------------------------------
    // MARK: - UIView Methods
    //-----------------------------------------------------------------------------
    
    // Make keyboard avoiding view transparent for touches
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result == self { return nil }
        
        return result
    }
    
    //-----------------------------------------------------------------------------
    // MARK: - Public Methods
    //-----------------------------------------------------------------------------
    
    /// Set bottom constraint or frame height to default value
    public func resetToDefault() {
        if let defaultConstant = defaultConstant {
            bottomConstraint?.constant = defaultConstant
            rootView.layoutIfNeeded()
        } else if let defaultHeight = defaultHeight {
            frame.size.height = defaultHeight
        }
    }
    
    //-----------------------------------------------------------------------------
    // MARK: - Private Methods - Notifications
    //-----------------------------------------------------------------------------
    
    @objc private func keyboardWillChangeFrameNotification(_ notification: Notification) {
        configure()
        
        guard !disable, let userInfo = notification.userInfo, let endFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue, endFrame != previousKeyboardFrame else { return }
        
        previousKeyboardFrame = endFrame
        
        let duration = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
        let animationCurveRawNSN = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber
        let animationCurveRaw = animationCurveRawNSN?.uintValue ?? UIViewAnimationOptions().rawValue
        let animationCurve: UIViewAnimationOptions = UIViewAnimationOptions(rawValue: animationCurveRaw)
        let options: UIViewAnimationOptions = [animationCurve, .beginFromCurrentState]
        
        let updateFrameClosure: () -> () = {
            if self.isConstraintsAligned, let defaultConstant = self.defaultConstant, let bottomConstraint = self.bottomConstraint, let isInverseOrder = self.isInverseOrder, let superview = self.superview {
                // Setup with bottom constraint constant
                let superviewRoot = superview.rootView
                let superviewFrameInRoot = superview.convert(superview.bounds, to: superviewRoot)
                let keyboardOverlapSuperviewHeight = superviewFrameInRoot.maxY - endFrame.minY - (self.layoutGuideHeight ?? 0)
                var newConstant = max(keyboardOverlapSuperviewHeight, defaultConstant)
                if !self.restoreDefaultConstant {
                    newConstant = max(bottomConstraint.constant, newConstant)
                }
                
                // Preventing modal view disappear crashes.
                // Assuming we'll never need to set bottom constraint constant more than keyboard height.
                newConstant = min(newConstant, endFrame.height)
                
                bottomConstraint.constant = isInverseOrder ? -newConstant : newConstant
            } else if let defaultHeight = self.defaultHeight {
                // Setup with frame height
                let frameInRoot = self.convert(self.bounds, to: self.rootView)
                let visibleHeight = endFrame.minY - frameInRoot.minY
                var newHeight = min(visibleHeight, defaultHeight)
                
                self.frame.size.height = newHeight
            }
        }
        
        if animate {
            superview?.layoutIfNeeded()
            UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
                guard let superviewRoot = self.superview?.rootView else { return }
                
                updateFrameClosure()
                superviewRoot.layoutIfNeeded()
            }, completion: nil)
        } else {
            _ = updateFrameClosure()
        }
    }
    
    //-----------------------------------------------------------------------------
    // MARK: - Private Methods - Helpers
    //-----------------------------------------------------------------------------
    
    private func getBottomConstraint() -> NSLayoutConstraint? {
        guard let superview = superview else { return nil }
        
        let constraints = superview.constraints
        for constraint in constraints {
            if (constraint.firstItem === self && constraint.secondItem === superview) || (constraint.secondItem === self && constraint.firstItem === superview) {
                // Constraint from superview to view. Check if it is bottom constraint.
                if constraint.firstAttribute == .bottom && constraint.secondAttribute == .bottom {
                    // Return
                    return constraint
                }
            } else if constraint.firstItem === self && constraint.secondItem is UILayoutSupport {
                // Constraint from view to layout guide. Check if it is bottom constraint.
                if constraint.firstAttribute == .bottom {
                    return constraint
                }
            } else if constraint.secondItem === self && constraint.firstItem is UILayoutSupport {
                // Constraint from layout guide to view. Check if it is bottom constraint.
                if constraint.secondAttribute == .bottom {
                    return constraint
                }
            }
        }
        
        return nil
    }
}
