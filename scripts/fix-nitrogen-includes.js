#!/usr/bin/env node
/**
 * Re-apply framework-form includes after `npx nitrogen` regenerates files.
 * See: https://github.com/mrousavy/nitro/issues/1293
 *
 * iOS (CocoaPods static frameworks): framework includes resolve via the pod module.
 * Android (CMake): needs physical VisionCameraTextRecognition/*.hpp aliases under shared/c++.
 */
const fs = require('fs')
const path = require('path')

const POD_MODULE = 'VisionCameraTextRecognition'
const ROOT = path.join(__dirname, '..', 'nitrogen', 'generated')
const SHARED_CPP = path.join(ROOT, 'shared', 'c++')
const MODULE_HEADER_DIR = path.join(SHARED_CPP, POD_MODULE)

const HEADERS = [
  'HybridTextRecognizerFactorySpec.hpp',
  'HybridTextRecognizerSpec.hpp',
  'Point.hpp',
  'RecognizedText.hpp',
  'Rect.hpp',
  'TextBlock.hpp',
  'TextElement.hpp',
  'TextLine.hpp',
  'TextRecognitionOutputOptions.hpp',
  'TextRecognitionOutputResolution.hpp',
]

const SKIP = new Set([
  'VisionCameraTextRecognition-Swift-Cxx-Bridge.hpp',
  'VisionCameraTextRecognition-Swift-Cxx-Umbrella.hpp',
])

function walk(dir, files = []) {
  if (!fs.existsSync(dir)) return files
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) walk(full, files)
    else if (entry.name.endsWith('.hpp') || entry.name.endsWith('.cpp')) files.push(full)
  }
  return files
}

function patchFile(filePath) {
  const base = path.basename(filePath)
  if (SKIP.has(base)) return false

  let content = fs.readFileSync(filePath, 'utf8')
  let changed = false

  for (const header of HEADERS) {
    const quoted = `#include "${header}"`
    const framework = `#include <${POD_MODULE}/${header}>`
    if (content.includes(quoted)) {
      content = content.split(quoted).join(framework)
      changed = true
    }
  }

  if (changed) {
    fs.writeFileSync(filePath, content)
  }
  return changed
}

/**
 * CMake on Android resolves <Module/Header.hpp> from include dirs literally.
 * Create shared/c++/VisionCameraTextRecognition/*.hpp -> ../Header.hpp symlinks.
 */
function ensureAndroidFrameworkHeaderAliases() {
  if (!fs.existsSync(SHARED_CPP)) return 0

  fs.mkdirSync(MODULE_HEADER_DIR, { recursive: true })
  let count = 0

  for (const header of HEADERS) {
    const source = path.join(SHARED_CPP, header)
    if (!fs.existsSync(source)) continue

    const alias = path.join(MODULE_HEADER_DIR, header)
    const relativeTarget = path.join('..', header)

    if (fs.existsSync(alias)) {
      try {
        const stat = fs.lstatSync(alias)
        if (stat.isSymbolicLink()) {
          const current = fs.readlinkSync(alias)
          if (current === relativeTarget || current === header) continue
        }
      } catch {
        // stale alias — recreate below
      }
      fs.rmSync(alias, { force: true })
    }

    fs.symlinkSync(relativeTarget, alias)
    count++
  }

  return count
}

const dirs = [
  path.join(ROOT, 'ios'),
  path.join(ROOT, 'shared', 'c++'),
]
let patchCount = 0
for (const dir of dirs) {
  for (const file of walk(dir)) {
    if (patchFile(file)) patchCount++
  }
}

const aliasCount = ensureAndroidFrameworkHeaderAliases()
console.log(
  `[fix-nitrogen-includes] Updated ${patchCount} file(s), ${aliasCount} Android header alias(es).`,
)
