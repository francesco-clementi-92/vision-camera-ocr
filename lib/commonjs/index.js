"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.scanOCR = scanOCR;
var _reactNativeVisionCamera = require("react-native-vision-camera");
/* eslint-disable no-undef */

/**
 * Scans OCR.
 */
const plugin = _reactNativeVisionCamera.VisionCameraProxy.initFrameProcessorPlugin('scanOCR');
function scanOCR(frame, params) {
  'worklet';

  if (plugin == null) {
    throw new Error('Failed to load Frame Processor Plugin "scanOCR"! Please check your dependencies and make sure that the plugin is linked correctly.');
  }
  if (params) {
    return plugin.call(frame, params);
  } else {
    return plugin.call(frame);
  }
}
//# sourceMappingURL=index.js.map