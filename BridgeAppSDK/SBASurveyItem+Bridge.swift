//
//  SBBSurveyElement+SBASurveyItemExtentions.swift
//  BridgeAppSDK
//
//  Copyright © 2016 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import BridgeSDK
import ResearchKit

// NOTE: syoung 03/17/2016 The Objective-C definitions for the SBBBridgeObjects are defined with a
// forced unwrap whereas they should be defined as optionals. Therefore, I am wrapping the properties
// in optionals and always check that the object is not nil before using it.

extension SBBSurveyInfoScreen : SBAInstructionStepSurveyItem {
    
    public var surveyItemType: SBASurveyItemType {
        return .Instruction
    }
    
    public var stepTitle: String? {
        return self.title
    }
    
    public var stepText: String? {
        return self.prompt
    }
    
    public var stepDetail: String? {
        return self.promptDetail
    }
    
    public var stepImage: UIImage? {
        // NOTE: syoung 03/15/2015 SBBImage translation not implemented. Requires caching design and currently not used
        // by any supported apps.
        return nil
    }
    
    public var learnMoreHTMLContent: String? {
        return nil
    }
    
    public func createCustomStep() -> ORKStep {
        return self.createInstructionStep()
    }
}

extension SBBSurveyQuestion : SBAFormStepSurveyItem {
    
    public var surveyItemType: SBASurveyItemType {
        if let _ = self.constraints as? SBBBooleanConstraints {
            return .Form(.Boolean)
        }
        else if let _ = self.constraints as? SBBStringConstraints {
            return .Form(.Text)
        }
        else if let multiConstraints = self.constraints as? SBBMultiValueConstraints {
            if (multiConstraints.allowMultipleValue) {
                return .Form(.MultipleChoice)
            }
            else {
                return .Form(.SingleChoice)
            }
        }
        else if let _ = self.constraints as? SBBDateTimeConstraints {
            return .Form(.DateTime)
        }
        else if let _ = self.constraints as? SBBDateConstraints {
            return .Form(.Date)
        }
        else if let _ = self.constraints as? SBBTimeConstraints {
            return .Form(.Time)
        }
        else if let _ = self.constraints as? SBBDurationConstraints {
            return .Form(.Duration)
        }
        else if let _ = self.constraints as? SBBIntegerConstraints {
            if (self.uiHint == "slider") {
                return .Form(.Scale)
            }
            else {
                return .Form(.Integer)
            }
        }
        else if let _ = self.constraints as? SBBDecimalConstraints {
            return .Form(.Decimal)
        }
        return SBASurveyItemType.Custom(nil)
    }
    
    public var stepTitle: String? {
        return nil
    }
    
    public var stepText: String? {
        return self.prompt
    }
    
    public var stepDetail: String? {
        return self.promptDetail
    }

    public var optional: Bool {
        return true // default implementation.
    }
    
    public var items: [AnyObject]? {
        
        // NOTE: Only supported use of items is for a multiple choice constraint. SBBBridgeObjects
        // do not (currently) have a constraint type that allows for compound steps (although the
        // use of use of the word "constraints" would suggest that. syoung 03/17/2016
        guard let multiConstraints = self.constraints as? SBBMultiValueConstraints, let items = multiConstraints.enumeration
        else {
            return nil
        }

        // If this multiple choice should have an "other" option then include the string as a choice
        if (multiConstraints.allowOtherValue) {
            var other = Localization.localizedString("SBA_OTHER")
            if (multiConstraints.enumeration.filter({ ($0 as! SBBSurveyQuestionOption).hasUppercaseLetters }).count == 0) {
                other = other.lowercaseString
            }
            return items + [NSString(string: other)]
        }
        
        return items
    }
    
    public var range: AnyObject? {
        return self.constraints
    }
    
    public var skipIdentifier: String? {
        guard let rule = self.constraints.rules?.first as? SBBSurveyRule else { return nil }
        return rule.skipTo
    }
    
    public var skipIfPassed: Bool {
        return true
    }
    
    public var rulePredicate: NSPredicate? {
        guard let skipIdentifier = self.skipIdentifier, let subtype = self.surveyItemType.formSubtype() else {
            return nil
        }
        
        // build the predicate
        var predicates: [NSPredicate] = []
        for obj in self.constraints.rules {
            if let rule = obj as? SBBSurveyRule, let predicate = rule.rulePredicate(subtype) {
                guard (rule.skipTo == skipIdentifier) else {
                    assertionFailure("skipTo conditional with different values not currently supported")
                    return nil
                }
                predicates += [predicate]
            }
        }
        
        // If no valid predicate rules found then return
        guard (predicates.count > 0) else {
            assertionFailure("rule predicate not currently supported")
            return nil
        }
        return NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
    }
    
    public func createCustomStep() -> ORKStep {
        return ORKStep(identifier: self.identifier)
    }
}

enum SBBSurveyRuleOperator: String {
    case Skip               = "de"
    case Equal              = "eq"
    case NotEqual           = "ne"
    case LessThan           = "lt"
    case GreaterThan        = "gt"
    case LessThanEqual      = "le"
    case GreaterThanEqual   = "ge"
    case OtherThan          = "ot"
}

extension SBBSurveyRule {
    
    var ruleOperator: SBBSurveyRuleOperator? {
        return SBBSurveyRuleOperator(rawValue: self.`operator`)
    }
    
    func rulePredicate(subtype: SBASurveyItemType.FormSubtype) -> NSPredicate? {
        // Exit early if operator or value are unsupported
        guard let op = self.ruleOperator, let value = self.value as? NSObject
        else { return nil }

        // For the case where the answer format is a choice, then the answer
        // is returned as an array of choices
        let isArray = (subtype == .SingleChoice) || (subtype == .MultipleChoice)
        
        switch(op) {
        case .Skip:
            return NSPredicate(format: "answer = NULL")
        case .Equal:
            let answer = isArray ? [value] : value
            return NSPredicate(format: "answer = %@", answer)
        case .NotEqual:
            let answer = isArray ? [value] : value
            return NSPredicate(format: "answer <> %@", answer)
        case .OtherThan:
            if (isArray) {
                return NSCompoundPredicate(notPredicateWithSubpredicate:
                    NSPredicate(format: "%@ IN answer", value))
            }
            else {
                return NSPredicate(format: "answer <> %@", value)
            }
        case .GreaterThan:
            return NSPredicate(format: "answer > %@", value)
        case .GreaterThanEqual:
            return NSPredicate(format: "answer >= %@", value)
        case .LessThan:
            return NSPredicate(format: "answer < %@", value)
        case .LessThanEqual:
            return NSPredicate(format: "answer <= %@", value)
        }
    }
}

extension SBBSurveyQuestionOption: SBATextChoice {
    
    public var choiceText: String {
        return self.label
    }
    
    public var choiceDetail: String? {
        return self.detail;
    }
    
    public var choiceValue: protocol<NSCoding, NSCopying, NSObjectProtocol> {
        return self.value
    }
    
    public var exclusive: Bool {
        return false
    }
    
    public var hasUppercaseLetters: Bool {
        return self.label.lowercaseString != self.label
    }
}

public protocol sbb_DateRange : SBADateRange {
    var allowFutureValue: Bool { get }
    var earliestValue: NSDate! { get }
    var latestValue: NSDate! { get }
}

extension SBBDateConstraints : sbb_DateRange {
}

extension SBBDateTimeConstraints : sbb_DateRange {
}

extension sbb_DateRange  {
    public var minDate: NSDate? {
        return self.earliestValue
    }
    public var maxDate: NSDate? {
        if ((!self.allowFutureValue) && (self.latestValue == nil)) {
            return NSDate() // Return NOW if future dates are not allowed
        }
        else {
            return self.latestValue
        }
    }
}

public protocol sbb_NumberRange: SBANumberRange {
    var maxValue: NSNumber! { get }
    var minValue: NSNumber! { get }
    var step: NSNumber! { get }
    var unit: String! { get }
}

extension SBBIntegerConstraints: sbb_NumberRange {
}

extension SBBDecimalConstraints: sbb_NumberRange {
}

extension sbb_NumberRange {
    
    public var minNumber: NSNumber? {
        guard ((self.minValue != nil) && (self.maxValue != nil)) else { return nil }
        return minValue
    }

    public var maxNumber: NSNumber? {
        guard ((self.minValue != nil) && (self.maxValue != nil)) else { return nil }
        return maxValue
    }
    
    public var stepInterval: Int {
        guard (self.step != nil) else { return 1 }
        return self.step.integerValue
    }
    
    public var unitLabel: String? {
        guard (self.unit != "") else { return nil }
        return self.unit
    }
}

