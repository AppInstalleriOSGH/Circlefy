//
//  ContentView.swift
//  Circlefy
//
//  Created by Benjamin on 12/3/24.
//

import SwiftUI
import MachO

struct ContentView: View {
    @State var ShowPicker = false
    @State var IPAPath = ""
    @State var Platform = PLATFORM_VISIONOS
    var body: some View {
        NavigationView {
            Form {
                Section(footer: Text("Created by [@AppInstalleriOS.bsky.social](https://bsky.app/profile/AppInstalleriOS.bsky.social), using [Ch0ma](https://github.com/opa334/ChOma) by [@opa334dev](https://x.com/opa334dev) and [ZIPFoundation](https://github.com/weichsel/ZIPFoundation).")) {
                    Picker("Pick a mask", selection: $Platform) {
                        Text("Circle")
                            .tag(PLATFORM_VISIONOS)
                        Text("No mask")
                            .tag(PLATFORM_MACOS)
                    }
                    Button("Select IPA") {
                        ShowPicker = true
                    }
                    Button("Modify IPA") {
                        DispatchQueue.global(qos: .background).async {
                            ModifyIPA(IPAPath, Platform)
                            PresentView(UIActivityViewController(activityItems: [URL(fileURLWithPath: IPAPath)], applicationActivities: []))
                            IPAPath = ""
                        }
                    }
                    .disabled(IPAPath.isEmpty)
                }
            }
            .sheet(isPresented: $ShowPicker) {
                IPAPicker($IPAPath)
            }
            .navigationTitle("Circlefy")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}

func ModifyIPA(_ IPAPath: String, _ Platform: Int32) {
    do {
        let (Alert, ProgressView) = ProgressAlert("Extracting IPA", "")
        guard let ExtractedPath = (Unzip(IPAPath) { Progress in
            ProgressView.SetProgress(Progress, 200)
        }) else {
            ShowAlert("Error", "Failed to extract IPA")
            return
        }
        defer {
            try? FileManager.default.removeItem(atPath: ExtractedPath)
        }
        let PayloadPath = "\(ExtractedPath)/Payload"
        guard let App = try FileManager.default.contentsOfDirectory(atPath: PayloadPath).first(where: {$0.hasSuffix(".app")}), let Info = NSDictionary(contentsOfFile: "\(PayloadPath)/\(App)/Info.plist"), let Executable = Info["CFBundleExecutable"] else {
            ShowAlert("Error", "Failed to locate executable")
            return
        }
        ModifyExecutable("\(PayloadPath)/\(App)/\(Executable)", UInt32(Platform))
        try FileManager.default.removeItem(atPath: IPAPath)
        Alert.SetTitle("Creating IPA")
        guard (Zip(PayloadPath, IPAPath) { Progress in
            ProgressView.SetProgress(100 + Progress, 200)
        }) else {
            ShowAlert("Error", "Failed to zip IPA")
            return
        }
        DismissView()
    } catch {
        print(error)
        ShowAlert("Error", error.localizedDescription)
    }
}
