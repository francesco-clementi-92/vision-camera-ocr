const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');

const sharedHeaders = [
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
];

function sharedIncludeRewrites(prefix, headers = sharedHeaders) {
  return headers.map((header) => [
    `#include "${header}"`,
    `#include "${prefix}${header}"`,
  ]);
}

function patchFile(relativePath, replacements) {
  const file = path.join(root, relativePath);
  if (!fs.existsSync(file)) {
    throw new Error(`Generated file not found: ${relativePath}`);
  }

  const before = fs.readFileSync(file, 'utf8');
  let after = before;

  for (const [from, to] of replacements) {
    after = after.split(from).join(to);
  }

  if (after !== before) {
    fs.writeFileSync(file, after);
  }
}

patchFile('nitrogen/generated/ios/c++/HybridTextRecognizerFactorySpecSwift.hpp', [
  ...sharedIncludeRewrites('../../shared/c++/'),
  [
    '#include "VisionCameraTextRecognition-Swift-Cxx-Umbrella.hpp"',
    '#include "../VisionCameraTextRecognition-Swift-Cxx-Umbrella.hpp"',
  ],
]);

patchFile('nitrogen/generated/ios/c++/HybridTextRecognizerSpecSwift.hpp', [
  ...sharedIncludeRewrites('../../shared/c++/'),
  [
    '#include "VisionCameraTextRecognition-Swift-Cxx-Umbrella.hpp"',
    '#include "../VisionCameraTextRecognition-Swift-Cxx-Umbrella.hpp"',
  ],
]);

patchFile('nitrogen/generated/ios/VisionCameraTextRecognition-Swift-Cxx-Bridge.hpp', [
  ...sharedIncludeRewrites('../shared/c++/'),
]);

patchFile('nitrogen/generated/ios/VisionCameraTextRecognition-Swift-Cxx-Umbrella.hpp', [
  ...sharedIncludeRewrites('../shared/c++/'),
]);

patchFile('nitrogen/generated/ios/VisionCameraTextRecognition-Swift-Cxx-Bridge.cpp', [
  [
    '#include "HybridTextRecognizerFactorySpecSwift.hpp"',
    '#include "c++/HybridTextRecognizerFactorySpecSwift.hpp"',
  ],
  [
    '#include "HybridTextRecognizerSpecSwift.hpp"',
    '#include "c++/HybridTextRecognizerSpecSwift.hpp"',
  ],
]);

patchFile('nitrogen/generated/ios/VisionCameraTextRecognitionAutolinking.mm', [
  [
    '#include "HybridTextRecognizerFactorySpecSwift.hpp"',
    '#include "c++/HybridTextRecognizerFactorySpecSwift.hpp"',
  ],
]);
