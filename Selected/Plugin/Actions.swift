//
//  Actions.swift
//  Selected
//
//  Created by sake on 2024/3/16.
//

import Foundation
import SwiftUI
import AVFoundation
import Yams
import AppKit

let kAfterPaste = "paste"
let kAfterCopy = "copy"


class GenericAction: Decodable {
    var title: String
    var icon: String
    var after: String
    var identifier: String
    
    init(title: String, icon: String, after: String, identifier: String) {
        self.title = title
        self.icon = icon
        self.after = after
        self.identifier = identifier
    }
    
    static func == (lhs: GenericAction, rhs: GenericAction) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

class URLAction: Decodable {
    var url: String
    
    init(url: String) {
        self.url = url
    }
    
    func generate(generic: GenericAction) -> PerformAction {
        
        return PerformAction(actionMeta:
                                generic, complete: { ctx in
            
            let url = URL(string: self.url
                .replacing("{text}", with: ctx.Text))!
            
            NSLog(url.scheme ?? "")
            if url.scheme != "http" && url.scheme != "https" {
                // not a web link
                NSWorkspace.shared.open(url)
                return
            }
            
            if !isBrowser(id: ctx.BundleID){
                NSWorkspace.shared.open(url)
                return
            }
        
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ctx.BundleID) else {
                NSWorkspace.shared.open(url)
                return
            }
            
            let cfg =  NSWorkspace.OpenConfiguration()
            cfg.activates = true
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: cfg)
        })
    }
}

class ServiceAction: Decodable {
    var name: String
    
    init(name: String) {
        self.name = name
    }
    
    func generate(generic: GenericAction) -> PerformAction {
        return PerformAction(actionMeta:
                                generic, complete: { ctx in
            PerfomService(serviceName: self.name, text: ctx.Text)
        })
    }
}

class KeycomboAction: Decodable {
    // TODO validate keycombo
    var keycombo: String
    
    init(keycombo: String) {
        NSLog("set keycombo \(keycombo)")
        self.keycombo = keycombo
    }
    
    func generate(generic: GenericAction) -> PerformAction {
        return PerformAction(actionMeta:
                                generic, complete: { ctx in
            let list = self.keycombo.split(separator: " ")
            var flags = CGEventFlags(rawValue: 0)
            var keycode = UInt16(0)
            list.forEach { sub in
                let str = String(sub)
                if let mask = KeyMaskMapping[str]{
                    flags.insert(mask)
                }
                if let key = KeycodeMapping[str] {
                    keycode = key
                }
            }
            PressKey(keycode: keycode, flags:  flags)
        })
    }
}

class CopyAction: Decodable{
    func generate(generic: GenericAction) -> PerformAction {
        return PerformAction(actionMeta:
                                generic, complete: { ctx in
            NSPasteboard.general.declareTypes([.string], owner: nil)
            let pasteboard = NSPasteboard.general
            pasteboard.setString(ctx.Text, forType: .string)
        })
    }
}


let speechSynthesizer = AVSpeechSynthesizer()

func speak(text: String) {
    speechSynthesizer.stopSpeaking(at: .word)
    let utterance = AVSpeechUtterance(string: text)
    utterance.pitchMultiplier = 0.8
    utterance.postUtteranceDelay = 0.2
    utterance.volume = 0.8
    speechSynthesizer.speak(utterance)
}


class SpeackAction: Decodable {
    func generate(generic: GenericAction) -> PerformAction {
        return PerformAction(actionMeta:
                                generic, complete: { ctx in
            speak(text: ctx.Text)
        })
    }
}

class GptAction: Decodable{
    var prompt: String
    
    init(prompt: String) {
        self.prompt = prompt
    }
    
    func generate(generic: GenericAction) -> PerformAction {
        return PerformAction(actionMeta:
                                generic, complete: { ctx in
            WindowManager.shared.createChatWindow(withText: ctx.Text, prompt: self.prompt)
        })
    }
}

class TranslationAction: Decodable {
    var target: String
    
    init(target: String) {
        self.target = target
    }
    
    func generate(generic: GenericAction) -> PerformAction {
        return PerformAction(actionMeta:
                                generic, complete: { ctx in
            WindowManager.shared.createTranslationWindow(withText: ctx.Text, to: self.target)
        })
    }
}


struct Action: Decodable{
    var meta: GenericAction
    var url: URLAction?
    var service: ServiceAction?
    var keycombo: KeycomboAction?
    var gpt: GptAction?
    var runCommand: RunCommandAction?
}


class PerformAction: Identifiable,Hashable {
    var id = UUID()
    var actionMeta: GenericAction
    var complete: (_: SelectedTextContext) -> Void
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(actionMeta.identifier)
    }
    
    static func == (lhs: PerformAction, rhs: PerformAction) -> Bool {
        return lhs.actionMeta == rhs.actionMeta
    }
    
    init(actionMeta: GenericAction, complete: @escaping (_: SelectedTextContext) -> Void) {
        self.actionMeta = actionMeta
        self.complete = complete
    }
}

func GetAllActions() -> [PerformAction] {
    var list = [PerformAction]()
    var pluginList = PluginManager.shared.getPlugins()
    pluginList.append(contentsOf: PluginList)
    pluginList.forEach { Plugin in
        if !Plugin.info.enabled {
            return
        }
        Plugin.actions.forEach { Action in
            if let url = Action.url {
                list.append(url.generate(generic: Action.meta))
                return
            }
            if let service =  Action.service {
                list.append(service.generate(generic: Action.meta))
                return
            }
            if let keycombo = Action.keycombo {
                list.append(keycombo.generate(generic: Action.meta))
                return
            }
            if let gpt =  Action.gpt {
                list.append(gpt.generate(generic: Action.meta))
                return
            }
            if let script = Action.runCommand {
                list.append(script.generate(generic: Action.meta))
                return
            }
        }
    }
    
    //    list.append(GptAction(prompt: "{text}").generate(
    //    generic: GenericAction(title: "chat", icon: "character.bubble", after: "", identifier: "selected.chat")
    //    ))
    list.append(TranslationAction(target: "cn").generate(
        generic: GenericAction(title: "2Chinese", icon: "square 译中", after: "", identifier: "selected.translation.cn")
    ))
    list.append(TranslationAction(target: "en").generate(
        generic: GenericAction(title: "2English", icon: "circle 译英", after: "", identifier: "selected.translation.en")
    ))
    list.append(URLAction(url: "{text}" ).generate(
        generic: GenericAction(title: "OpenLinks", icon: "symbol:link", after: "", identifier: "selected.openlinks")
    ))
    list.append(CopyAction().generate(
        generic: GenericAction(title: "Copy", icon: "symbol:doc.on.clipboard", after: "", identifier: "selected.copy")
    ))
    list.append(SpeackAction().generate(
        generic: GenericAction(title: "Speak", icon: "symbol:play.circle", after: "", identifier: "selected.speak")
    ))
    return list
}

// GetActions 根据上下文获得当前支持的 action 列表。比如根据当前窗口的应用选择 action 列表。
func GetActions(ctx: SelectedTextContext) -> [PerformAction] {
    let condition = ConfigurationManager.shared.getAppCondition(bundleID: ctx.BundleID)
    let actionList = GetAllActions()
    
    guard let condition = condition else {
        return actionList
    }
    
    if condition.actions.isEmpty {
        return actionList
    }
    
    var list = [PerformAction]()
    let allActionDict = actionList.reduce(into: [String: PerformAction]()) {
        $0[$1.actionMeta.identifier] = $1
    }
    for action in condition.actions {
        guard let allowed = allActionDict[action] else {
            continue
        }
        list.append(allowed)
    }
    return list
}
