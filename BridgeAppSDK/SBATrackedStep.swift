//
//  SBATrackedStep.swift
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

import ResearchKit

public protocol SBATrackedStepSurveyItem: SBASurveyItem {
    var trackingType: SBATrackingStepType? { get }
    var textFormat: String? { get }
}

public enum SBATrackingStepType: String {
    
    case Introduction   = "introduction"
    case Changed        = "changed"
    case Completion     = "completion"
    case Activity       = "activity"
    case Selection      = "selection"
    case Frequency      = "frequency"
    
    func isTrackedFormStepType() -> Bool {
        switch self {
        case .Selection, .Frequency, .Activity:
            return true
        default:
            return false
        }
    }
}

extension SBATrackingStepType: Equatable {
}

public func ==(lhs: SBATrackingStepType, rhs: SBATrackingStepType) -> Bool {
    return lhs.rawValue == rhs.rawValue
}

public struct SBATrackingStepIncludes {
    
    let nextStepIfNoChange: SBATrackingStepType
    let includes:[SBATrackingStepType]
    
    private init(includes:[SBATrackingStepType]) {
        if (includes.contains(.Changed) && !includes.contains(.Activity)) {
            self.includes = [.Changed, .Selection, .Frequency, .Activity]
            self.nextStepIfNoChange = .Completion
        }
        else {
            self.includes = includes
            self.nextStepIfNoChange = .Activity
        }
    }
    
    public static let StandAloneSurvey = SBATrackingStepIncludes(includes: [.Introduction, .Selection, .Frequency, .Completion])
    public static let ActivityOnly = SBATrackingStepIncludes(includes: [.Activity])
    public static let SurveyAndActivity = SBATrackingStepIncludes(includes: [.Introduction, .Selection, .Frequency, .Activity])
    public static let ChangedAndActivity = SBATrackingStepIncludes(includes: [.Changed, .Selection, .Frequency, .Activity])
    public static let ChangedOnly = SBATrackingStepIncludes(includes: [.Changed])
    
    func includeSurvey() -> Bool {
        return includes.contains(.Introduction) || includes.contains(.Changed)
    }
    
    func shouldInclude(trackingType: SBATrackingStepType) -> Bool {
        return includes.contains(trackingType)
    }
}

extension NSDictionary : SBATrackedStepSurveyItem {
    
    public var trackingType: SBATrackingStepType? {
        guard let trackingType = self["trackingType"] as? String else { return nil }
        return SBATrackingStepType(rawValue: trackingType)
    }
    
    public var textFormat: String? {
        return self["textFormat"] as? String
    }
    
}

extension SBATrackedDataObject: SBATextChoice {
    public var choiceText: String {
        return self.text
    }
    public var choiceDetail: String? {
        return nil
    }
    public var choiceValue: protocol<NSCoding, NSCopying, NSObjectProtocol> {
        return self.identifier
    }
    public var exclusive: Bool {
        return false
    }
}

public class SBATrackedFormStep: ORKFormStep {
    
    var textFormat: String?
    var trackingType: SBATrackingStepType!
    var frequencyAnswerFormat: ORKAnswerFormat?
    
    public override init(identifier: String) {
        super.init(identifier: identifier)
    }
    
    public init(surveyItem: SBATrackedStepSurveyItem, items:[SBATrackedDataObject]) {
        super.init(identifier: surveyItem.identifier)
        self.trackingType = surveyItem.trackingType
        self.textFormat = surveyItem.textFormat
        if let formSurvey = surveyItem as? SBAFormStepSurveyItem {
            formSurvey.mapStepValues(self)
            if (self.trackingType == .Activity) {
                formSurvey.buildFormItems(self, isSubtaskStep: false)
            }
        }
        if let range = surveyItem as? SBANumberRange where (self.trackingType == .Frequency) {
            self.frequencyAnswerFormat = range.createAnswerFormat(.Scale)
        }
        updateWithSelectedItems(items)
    }
    
    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.textFormat = aDecoder.decodeObjectForKey("textFormat") as? String
        if let trackingTypeValue = aDecoder.decodeObjectForKey("trackingType") as? String,
        let trackingType = SBATrackingStepType(rawValue: trackingTypeValue) {
            self.trackingType = trackingType
        }
        self.frequencyAnswerFormat = aDecoder.decodeObjectForKey("frequencyAnswerFormat") as? ORKAnswerFormat
    }
    
    override public func encodeWithCoder(aCoder: NSCoder) {
        super.encodeWithCoder(aCoder)
        aCoder.encodeObject(self.textFormat, forKey: "textFormat")
        aCoder.encodeObject(self.trackingType.rawValue, forKey: "trackingType")
        aCoder.encodeObject(self.frequencyAnswerFormat, forKey: "frequencyAnswerFormat")
    }
    
    override public func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = super.copyWithZone(zone) as! SBATrackedFormStep
        copy._shouldSkipStep = self._shouldSkipStep
        copy.trackingType = self.trackingType
        copy.textFormat = self.textFormat
        copy.frequencyAnswerFormat = self.frequencyAnswerFormat
        return copy
    }
    
    public var shouldSkipStep: Bool {
        return _shouldSkipStep
    }
    private var _shouldSkipStep = false
    
    public func updateWithSelectedItems(selectedItems:[SBATrackedDataObject]) {
        switch self.trackingType! {

        // For selection type, only care about building the form items for the first round
        case .Selection where (self.formItems == nil):
            buildSelectionFormItem(selectedItems)
            
        case .Frequency:
            updateFrequencyFormItems(selectedItems)
            
        case .Activity:
            updateActivityFormStep(selectedItems)
            
        default:
            break
        }
    }
    
    private func buildSelectionFormItem(selectedItems:[SBATrackedDataObject]) {
        
        var choices = selectedItems.map { (item) -> ORKTextChoice in
            return item.createORKTextChoice()
        }
        
        // Add a choice for none of the above
        let noneChoice = ORKTextChoice(text: Localization.localizedString("SBA_NONE_OF_THE_ABOVE"),
                                       detailText: nil,
                                       value: "None",
                                       exclusive: true)
        choices += [noneChoice];
        
        // If this is an optional step, then include a choice for skipping
        if (self.optional) {
            let skipChoice = ORKTextChoice(text: Localization.localizedString("SBA_SKIP_CHOICE"),
                                           detailText: nil,
                                           value: "Skipped",
                                           exclusive: true)
            choices += [skipChoice]
            self.optional = false;
        }
        
        let answerFormat = ORKTextChoiceAnswerFormat(style: .MultipleChoice, textChoices: choices)
        let formItem = ORKFormItem(identifier: self.identifier, text: nil, answerFormat: answerFormat)
        self.formItems = [formItem]
    }
    
    private func updateFrequencyFormItems(selectedItems:[SBATrackedDataObject]) {
        
        self.formItems = selectedItems.filter({ $0.usesFrequencyRange }).map { (item) -> ORKFormItem in
            return ORKFormItem(identifier: item.identifier, text: item.text, answerFormat: self.frequencyAnswerFormat)
        }
        _shouldSkipStep = (self.formItems == nil) || (self.formItems!.count == 0)
    }
    
    private func updateActivityFormStep(selectedItems:[SBATrackedDataObject]) {
        let trackedItems = selectedItems.filter({ $0.tracking }).map({ $0.shortText })
        _shouldSkipStep = (trackedItems.count == 0)
        if let textFormat = self.textFormat where (trackedItems.count > 0) {
            self.text = String(format: textFormat, Localization.localizedJoin(trackedItems))
        }
    }
}
