//
//  main.swift
//  VolumeEjectService
//
//  Created by Yaxin Cheng on 2020-06-03.
//  Copyright © 2020 Yaxin Cheng. All rights reserved.
//

import Cocoa

struct Volume: Encodable {
  let title: String
  let subtitle: String
  let id: String
}

func listVolumes(name: String) -> [Volume] {
  FileManager.default
    .mountedVolumeURLs(includingResourceValuesForKeys: [.volumeIsInternalKey],
                       options: .skipHiddenVolumes)?
    .filter { try! $0.resourceValues(forKeys: [.volumeIsInternalKey]).volumeIsInternal != true }
    .filter { name.isEmpty || $0.lastPathComponent.contains(name) }
    .map { Volume(title: $0.lastPathComponent, subtitle: $0.path, id: $0.path) }
  ?? []
}

func eject(path: String) {
  for path in path.split(separator: "\n") {
    do {
      try NSWorkspace.shared.unmountAndEjectDevice(at: URL(fileURLWithPath: String(path)))
    } catch {
      print(error)
    }
  }
}

func help() {
  print("""
  Volume Eject Service
  
  Parameters:
  -q, --query <name>       query for specific volume to be removed
  -x, --execute <path>        eject selected volume
  """)
  exit(0)
}

let arguments = CommandLine.arguments.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
if arguments.count < 2 || arguments.count > 3 {
  help()
}

private let OUTPUT_ENV_KEY = "OUTPUT"
private let IDENTIFIER_ENV_KEY = "IDENTIFIER"

func write<S: Encodable>(response: S) throws {
  let encoder = JSONEncoder()
  let json = try encoder.encode(response)
  FileHandle.standardOutput.write(json)
  FileHandle.standardOutput.write(Data("\n".utf8))
}

if arguments[1] == "-q" || arguments[1] == "--query" {
  let volumes = listVolumes(name: arguments.count >= 3 ? arguments[2].trimmingCharacters(in: .whitespacesAndNewlines) : "")
  let services: [Volume]
  if volumes.count <= 1 {
    services = volumes
  } else {
    let ejectAllId = volumes.map { $0.id }.joined(separator: "\n")
    services = [Volume(title: "Eject All",
                       subtitle: "Eject all ejectable volumes listed below",
                       id: ejectAllId)] + volumes
  }
  for service in services {
    try! write(response: service)
  }
} else if arguments[1] == "-x" || arguments[1] == "-X"
  || arguments[1] == "--execute" || arguments[1] == "--alter-execute" {
  eject(path: arguments[2])
} else {
  help()
}
