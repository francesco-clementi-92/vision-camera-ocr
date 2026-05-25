#!/usr/bin/env node
/**
 * Re-apply framework-form includes after `npx nitrogen` regenerates files.
 * See: https://github.com/mrousavy/nitro/issues/1293
 */
const fs = require('fs')
const path = require('path')

const POD_MODULE = 'VisionCameraTextRecognition'
const ROOT = path.join(__dirname, '..', 'nitrogen', 'generated')

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

const dirs = [
  path.join(ROOT, 'ios'),
  path.join(ROOT, 'shared', 'c++'),
]
let count = 0
for (const dir of dirs) {
  for (const file of walk(dir)) {
    if (patchFile(file)) count++
  }
}
console.log(`[fix-nitrogen-includes] Updated ${count} file(s).`)
