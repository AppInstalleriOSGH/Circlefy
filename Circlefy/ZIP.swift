//
//  ZIP.swift
//  Circlefy
//
//  Created by Benjamin on 12/3/24.
//

import Foundation
import ZIPFoundation

func Zip(_ SourcePath: String, _ DestinationPath: String, _ ProgressCallback: @escaping (Float) -> Void) -> Bool {
    let ZipProgress = Progress()
    let Observation = ZipProgress.observe(\.fractionCompleted) { Progress, _ in
        ProgressCallback(Float(Progress.fractionCompleted * 100))
    }
    do {
        if FileManager.default.fileExists(atPath: DestinationPath) {
            try FileManager.default.removeItem(atPath: DestinationPath)
        }
        try FileManager.default.zipItem(at: URL(fileURLWithPath: SourcePath), to: URL(fileURLWithPath: DestinationPath), compressionMethod: .deflate, progress: ZipProgress)
        Observation.invalidate()
        return true
    } catch {
        print("Extraction of ZIP archive failed with error: \(error)")
        Observation.invalidate()
        return false
    }
}

func Unzip(_ ZIPPath: String, _ DestinationPath: String = "\(NSHomeDirectory())/Documents/\(UUID().uuidString)", _ ProgressCallback: @escaping (Float) -> Void) -> String? {
    let UnzipProgress = Progress()
    let Observation = UnzipProgress.observe(\.fractionCompleted) { Progress, _ in
        ProgressCallback(Float(Progress.fractionCompleted * 100))
    }
    do {
        try FileManager.default.unzipItem(at: URL(fileURLWithPath: ZIPPath), to: URL(fileURLWithPath: DestinationPath), progress: UnzipProgress)
        Observation.invalidate()
        return DestinationPath
    } catch {
        print("Extraction of ZIP archive failed with error: \(error)")
        Observation.invalidate()
        return nil
    }
}
