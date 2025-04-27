require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "VisionCameraOcr"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "15.5" }
  s.source       = { :git => "https://github.com/francesco-clementi-92/vision-camera-ocr", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift}"

  s.dependency "VisionCamera"
  s.dependency "React-Core"
  s.dependency "GoogleMLKit/TextRecognition", "8.0.0"
end
