//
//  nest-license-downloader.swift
//  nest-license-downloader
//
//  Created by Ryotaro Seki on 2024/12/13.
//

import ArgumentParser
import AsyncOperations
import Foundation
import ZIPFoundation

#if canImport(Darwin)
import Darwin
#endif

@main
struct NestLicenseDownloader: AsyncParsableCommand {
    @Argument(help: "info.json path.", completion: .file())
    var inputPath: String

    @Option(name: .short, help: "output directory path.")
    var outputPath: String?

    func run() async {
        guard let data = try? Data(contentsOf: URL(filePath: inputPath)) else {
            print("Failed to read \(inputPath)!")
            errorExit()
            return
        }
        guard let info = try? JSONDecoder().decode(NestInfo.self, from: data) else {
            print("Failed to decode json!")
            errorExit()
            return
        }
        guard let outputPath = createDirectoryIfNeeded(outputPath: outputPath) else {
            errorExit()
            return
        }

        let urls = info.commands
            .flatMap(\.value)
            .map(\.manufacturer.artifactBundle.sourceInfo.zipURL)

        await urls.asyncForEach { url in
            print("Downloading: \(url)")
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    print("Failed to download \(url)")
                    return
                }

                let archive = try Archive(data: data, accessMode: .read)

                guard let archiveRoot = archive.min(by: { $0.path.count < $1.path.count }) else {
                    print("\(url.lastPathComponent) is empty.")
                    return
                }
                let licenses = archive.filter { $0.type == .file && isLicenseFile(path: $0.path) }
                guard !licenses.isEmpty else {
                    print("\(url.lastPathComponent) is not contain license file")
                    return
                }

                let fileManager = FileManager.default

                let archiveRootPath = URL(filePath: archiveRoot.path).deletingPathExtension().lastPathComponent
                try fileManager.createDirectory(atPath: "\(outputPath)/\(archiveRootPath)", withIntermediateDirectories: true)

                try licenses.forEach { entry in
                    var data = Data()
                    _ = try archive.extract(entry) { data.append($0) }

                    let licenseFileName = URL(filePath: entry.path).lastPathComponent
                    let licenseFilePath = "\(outputPath)/\(archiveRootPath)/\(licenseFileName)"

                    fileManager.createFile(atPath: licenseFilePath, contents: nil)

                    let licenseFileURL = URL(filePath: licenseFilePath)
                    try data.write(to: licenseFileURL)
                    print(licenseFilePath)
                }
            } catch {
                print(error)
                return
            }
        }
    }

    // TODO: String?じゃなくてthrows Stringにする(このメソッドの中でprintしない)
    func createDirectoryIfNeeded(outputPath: String?) -> String? {
        let fileManager = FileManager.default
        if let outputPath {
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(atPath: outputPath, isDirectory: &isDirectory)

            if exists && isDirectory.boolValue {
                return outputPath
            } else if exists && !isDirectory.boolValue {
                print("\(outputPath) is not directory!")
                return nil
            } else {
                do {
                    try fileManager.createDirectory(atPath: outputPath, withIntermediateDirectories: true)
                    return outputPath
                } catch {
                    print("Failed to create directory!")
                    print(error)
                    return nil
                }
            }
        } else {
            return fileManager.currentDirectoryPath
        }
    }

    func isLicenseFile(path: String) -> Bool {
        let name = URL(filePath: path).deletingPathExtension().lastPathComponent

        return name == "LICENSE" || name == "LICENCE"
    }
}

func errorExit() {
#if canImport(Darwin)
    Darwin.exit(1)
#endif
}

struct NestInfo: Decodable {
    struct Command: Decodable {
        struct Manufacturer: Decodable {
            struct ArtifactBundle: Decodable {
                struct SourceInfo: Decodable {
                    var zipURL: URL
                }
                var sourceInfo: SourceInfo
            }
            var artifactBundle: ArtifactBundle
        }
        var manufacturer: Manufacturer
    }
    var commands: [String: [Command]]
}
