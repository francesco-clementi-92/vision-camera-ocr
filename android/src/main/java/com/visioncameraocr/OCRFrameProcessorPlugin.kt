package com.visioncameraocr

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.graphics.Point
import android.graphics.Rect
import android.media.Image
import android.util.Log
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.mrousavy.camera.frameprocessors.Frame
import com.mrousavy.camera.frameprocessors.FrameProcessorPlugin
import com.mrousavy.camera.frameprocessors.VisionCameraProxy

class OCRFrameProcessorPlugin(proxy: VisionCameraProxy, options: Map<String, Any>?) : FrameProcessorPlugin() {

    private fun getBlockArray(blocks: MutableList<Text.TextBlock>): List<HashMap<String, Any?>> {
        val blockArray = mutableListOf<HashMap<String, Any?>>()

        for (block in blocks) {
            val blockMap = HashMap<String, Any?>()

            blockMap["text"] = block.text
            blockMap["recognizedLanguages"] = getRecognizedLanguages(block.recognizedLanguage)
            blockMap["cornerPoints"] = block.cornerPoints?.let { getCornerPoints(it) }
            blockMap["frame"] = block.boundingBox?.let { getFrame(it) }
            blockMap["boundingBox"] = block.boundingBox?.let { getBoundingBox(it) }
            blockMap["lines"] = getLineArray(block.lines)

            blockArray.add(blockMap)
        }
        return blockArray
    }

    private fun getLineArray(lines: MutableList<Text.Line>): List<HashMap<String, Any?>> {
        val lineArray = mutableListOf<HashMap<String, Any?>>()

        for (line in lines) {
            val lineMap = hashMapOf<String, Any?>()

            lineMap["text"] = line.text
            lineMap["confidence"] = line.confidence.toDouble()
            lineMap["recognizedLanguages"] = getRecognizedLanguages(line.recognizedLanguage)
            lineMap["cornerPoints"] = line.cornerPoints?.let { getCornerPoints(it) }
            lineMap["frame"] = line.boundingBox?.let { getFrame(it)  }
            lineMap["boundingBox"] = line.boundingBox?.let { getBoundingBox(it) }
            lineMap["elements"] = getElementArray(line.elements)

            lineArray.add(lineMap)
        }
        return lineArray
    }

    private fun getElementArray(elements: MutableList<Text.Element>): List<HashMap<String, Any?>> {
        val elementArray = mutableListOf<HashMap<String, Any?>>()

        for (element in elements) {
            val elementMap = hashMapOf<String, Any?>()

            elementMap["text"] = element.text
            elementMap["cornerPoints"] = element.cornerPoints?.let { getCornerPoints(it) }
            elementMap["frame"] =  element.boundingBox?.let { getFrame(it)  }
            elementMap["boundingBox"] = element.boundingBox?.let { getBoundingBox(it) }
            elementMap["symbols"] = this.getSymbolArray(element)

            elementArray.add(elementMap)

        }
        return elementArray
    }

    private  fun getSymbolArray(element: Text.Element): MutableList<HashMap<String, Any?>> {
        val symbolsArray =mutableListOf<HashMap<String, Any?>>()

        for (symbol in element.symbols) {
            val symbolMap = hashMapOf<String, Any?>()

            symbolMap["text"] = symbol.text
            symbolMap["cornerPoints"] = symbol.cornerPoints?.let { getCornerPoints(it) }
            symbolMap["frame"] =  symbol.boundingBox?.let { getFrame(it)  }
            symbolMap["boundingBox"] = symbol.boundingBox?.let { getBoundingBox(it) }
            symbolsArray.add(symbolMap)

        }
        return symbolsArray
    }



    private fun getRecognizedLanguages(recognizedLanguage: String): List<String> {
        return  listOf(recognizedLanguage)
    }

    private fun getCornerPoints(points: Array<Point>): List<HashMap<String, Int>> {
        val cornerPoints = mutableListOf<HashMap<String, Int>>()

        for (point in points) {
            val pointMap = hashMapOf<String, Int>()
            pointMap["x"] = point.x
            pointMap["y"] = point.y
            cornerPoints.add(pointMap)
        }
        return cornerPoints
    }

    private fun getFrame(boundingBox: Rect?): HashMap<String, Any> {
        val frame = hashMapOf<String, Any>()

        if (boundingBox != null) {
            frame["x"] = boundingBox.exactCenterX().toDouble()
            frame["y"] = boundingBox.exactCenterY().toDouble()
            frame["width"] = boundingBox.width()
            frame["height"] = boundingBox.height()
            frame["boundingCenterX"] = boundingBox.centerX()
            frame["boundingCenterY"] = boundingBox.centerY()
        }
        return frame
    }

    private fun getBoundingBox(boundingBox: Rect?): HashMap<String, Any> {
        val box = hashMapOf<String,Any>()

        if (boundingBox != null) {
            box["left"] = boundingBox.left
            box["top"] = boundingBox.top
            box["right"] = boundingBox.right
            box["bottom"] = boundingBox.bottom
        }

        return box
    }

    private fun resize(image: Bitmap, maxWidth: Int, maxHeight: Int): Bitmap {
        var image = image
        if (maxHeight > 0 && maxWidth > 0) {
            val width = image.width
            val height = image.height
            val ratioBitmap = width.toFloat() / height.toFloat()
            val ratioMax = maxWidth.toFloat() / maxHeight.toFloat()

            var finalWidth = maxWidth
            var finalHeight = maxHeight
            if (ratioMax > ratioBitmap) {
                finalWidth = (maxHeight.toFloat() * ratioBitmap).toInt()
            } else {
                finalHeight = (maxWidth.toFloat() / ratioBitmap).toInt()
            }
            image = Bitmap.createScaledBitmap(image, finalWidth, finalHeight, true)
            return image
        } else {
            return image
        }
    }

    private fun preprocessImage(bitmap: Bitmap): Bitmap {
        // Convert to grayscale
        val grayBitmap = Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(grayBitmap)
        val paint = Paint()
        val colorMatrix = ColorMatrix()
        colorMatrix.setSaturation(0f) // Set saturation to 0 to get grayscale
        val colorFilter = ColorMatrixColorFilter(colorMatrix)
        paint.colorFilter = colorFilter
        canvas.drawBitmap(bitmap, 0f, 0f, paint)

        val resizedBitmap = Bitmap.createScaledBitmap(grayBitmap, 520, 110, true) // Resize to desired dimensions

        return resizedBitmap
    }

    override fun callback(frame: Frame, params: Map<String, Any>?): Any? {
        val result = hashMapOf<String, Any>()
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

        if (params?.containsKey("cropRegion") == true) {
            var bm: Bitmap = BitmapUtils.getBitmap(frame)
            val cropRegion = params["cropRegion"] as Map<String, Object>
            val left = (cropRegion["left"] as Double) / 100.0 * bm.width
            val top = (cropRegion["top"] as Double) / 100.0 * bm.height
            val width = (cropRegion["width"] as Double) / 100.0 * bm.width
            val height = (cropRegion["height"] as Double) / 100.0 * bm.height
            bm = Bitmap.createBitmap(
                bm,
                left.toInt(),
                top.toInt(),
                width.toInt(),
                height.toInt(),
                null,
                false
            )
            val grayImage = preprocessImage(bm)
            val image = InputImage.fromBitmap(grayImage, frame.imageProxy.imageInfo.rotationDegrees)
            val task: Task<Text> = recognizer.process(image)
            try {
                val text: Text = Tasks.await(task)
                if (text.text.isNotEmpty()) {
                    OCRResult.addResult(text.text.replace(Regex("[^a-zA-Z0-9]+"), ""))
                }
                result["text"] = OCRResult.getMostFrequentOrLatest()
            } catch (e: Exception) {
                e.printStackTrace()
                return null
            } finally {
                bm.recycle()
            }
        } else {
            @SuppressLint("UnsafeOptInUsageError")
            val mediaImage: Image? = frame.image

            if (mediaImage != null) {

                val image = InputImage.fromMediaImage(mediaImage, frame.imageProxy.imageInfo.rotationDegrees)
                val task: Task<Text> = recognizer.process(image)
                try {
                    val text: Text = Tasks.await(task)
                    //  OCRFrameProcessorPlugin.logExtrasForTesting(text)
                    result["text"] = text.text
                    result["blocks"] = getBlockArray(text.textBlocks)
                } catch (e: Exception) {
                    e.printStackTrace()
                    return null
                } finally {
                    mediaImage.close() // Ensure the image is always closed after processing
                }
            }
        }
        return hashMapOf("result" to result)
    }

    companion object {
        public var isRegistered = false
        private fun logExtrasForTesting(text: Text?) {
            if (text != null) {

                for (block in text.textBlocks) {
                    for (line in block.lines) {
                        for (element in line.elements) {
                            for (symbol in element.symbols) {
                                Log.d("MANUAL_TESTING_LOG", "Symbol text is: ${symbol.text} height:${(symbol.boundingBox?.bottom ?: 0) - (symbol.boundingBox?.top ?: 0)}")
                            }
                        }
                    }
                }
            }
        }
    }
}
