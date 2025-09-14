/* eslint-disable no-undef */
import { VisionCameraProxy } from 'react-native-vision-camera';
/**
 * Scans OCR.
 */
const plugin = VisionCameraProxy.initFrameProcessorPlugin('scanOCR');
export function scanOCR(frame, params) {
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