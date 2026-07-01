
# vision-camera-ocr-plugin

On-device text recognition for [VisionCamera](https://github.com/mrousavy/react-native-vision-camera), powered by [**MLKit Vision** Text Recognition](https://developers.google.com/ml-kit/vision/text-recognition).

Built on [Nitro Modules](https://nitro.margelo.com/). Requires **VisionCamera >= 5.1.0**.

> **Language support:** Latin script only. Chinese, Japanese, Korean and Devanagari models are not bundled.

<img style='width:200px;' src="docs/demo.gif">

## Installation

```sh
yarn add vision-camera-ocr-plugin react-native-nitro-modules
cd ios && pod install
```

Peer dependencies (must already be installed in your app):

- `react-native-vision-camera` >= 5.1.0
- `react-native-nitro-modules` >= 0.36.0

The [frame-processor](#3-frame-processor-usetextrecognizer) usage additionally needs
[`react-native-worklets-core`](https://github.com/margelo/react-native-worklets-core).
Add its plugin to `babel.config.js` (not needed for the other two usages):

```js
module.exports = {
  plugins: [['react-native-worklets-core/plugin']],
  // ...
}
```

> Restart metro-bundler after editing `babel.config.js`.

## Usage

There are three ways to use this library, from simplest to most flexible.

### 1. `TextRecognitionCamera` (drop-in component)

Renders a `<Camera />` on the rear device and streams recognized text.

```tsx
import { TextRecognitionCamera } from 'vision-camera-ocr-plugin'

function App() {
  return (
    <TextRecognitionCamera
      style={{ flex: 1 }}
      isActive={true}
      onTextRecognized={(result) => console.log(result.text)}
      onError={(error) => console.error(error)}
    />
  )
}
```

### 2. `useTextRecognitionOutput` (Camera Output)

Attach a text-recognition output to your own `<Camera />` or `CameraSession`.

```tsx
import { useTextRecognitionOutput } from 'vision-camera-ocr-plugin'
import { Camera, useCameraDevice } from 'react-native-vision-camera'

function App() {
  const device = useCameraDevice('back')
  const textOutput = useTextRecognitionOutput({
    outputResolution: 'preview', // or 'full'
    onTextRecognized: (result) => console.log(result.text),
    onError: (error) => console.error(error),
  })

  if (device == null) return null
  return <Camera style={{ flex: 1 }} isActive device={device} outputs={[textOutput]} />
}
```

### 3. Frame Processor (`useTextRecognizer`)

Run recognition manually inside a Frame Output worklet. This is the only path that
gives you the built-in coordinate-conversion helpers (see [Coordinates](#coordinates)).

```tsx
import { useTextRecognizer } from 'vision-camera-ocr-plugin'
import { useFrameOutput } from 'react-native-vision-camera'

const recognizer = useTextRecognizer()
const frameOutput = useFrameOutput({
  onFrame: (frame) => {
    'worklet'
    const result = recognizer.recognizeText(frame) // or recognizeTextAsync(frame)
    console.log(result.text)
    frame.dispose() // required: frames are pooled GPU buffers
  },
})
```

## Options

`TextRecognitionOutputOptions` (used by #1 and #2):

| Option             | Type                       | Default     | Description                                                        |
| ------------------ | -------------------------- | ----------- | ------------------------------------------------------------------ |
| `outputResolution` | `'preview'` \| `'full'`    | `'preview'` | `'preview'` = lower latency; `'full'` = highest detail (accuracy). |
| `onTextRecognized` | `(result) => void`         | —           | Called for every recognized frame.                                 |
| `onError`          | `(error) => void`          | —           | Called on recognition errors (throttled to ~1/s).                  |

## Data

`RecognizedText` mirrors the MLKit
[text structure](https://developers.google.com/ml-kit/vision/text-recognition#text_structure)
— `text` split into `blocks` → `lines` → `elements`:

```ts
interface RecognizedText {
  text: string
  blocks: TextBlock[]
}

interface TextBlock {         // also TextLine, TextElement
  text: string
  boundingBox: Rect           // { left, right, top, bottom }
  cornerPoints: Point[]       // { x, y }
  recognizedLanguages: string[] // BCP-47 codes
  lines: TextLine[]           // TextLine has `elements`, TextElement is a leaf
}
```

## Coordinates

`boundingBox` / `cornerPoints` are in the recognized image's coordinate system, **not**
your preview view's.

- **Frame Processor (#3):** convert precisely with the VisionCamera helpers —
  `frame.convertFramePointToCameraPoint(point)` then
  `previewView.convertCameraPointToViewPoint(cameraPoint)`.
- **Component / Output (#1, #2):** these helpers are not available. Coordinates are in
  the oriented (upright) image space, while `output.currentResolution` reports the
  **sensor-native, un-rotated** size — so in portrait the width/height axes are swapped
  relative to the coordinates. For pixel-accurate overlays use the Frame Processor path;
  use the component/output when you only need `result.text`.

## Pixel format

MLKit needs a standard camera buffer. In the Frame Processor path use
`pixelFormat="yuv"` (or `"rgb"`); a `"native"` format may deliver RAW/vendor buffers
that cannot be converted, which surfaces as an `onError` / thrown error.

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT
