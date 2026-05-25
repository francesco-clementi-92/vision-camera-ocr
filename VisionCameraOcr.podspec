require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "VisionCameraOcr"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported, :visionos => 1.0 }
  s.source       = { :git => "https://github.com/francesco-clementi-92/vision-camera-ocr", :tag => "#{s.version}" }

  s.source_files = [
    # Implementation (Swift)
    "ios/**/*.{swift}",
    # Autolinking/Registration (Objective-C++)
    "ios/**/*.{m,mm}",
    # Implementation (C++ objects)
    "cpp/**/*.{hpp,cpp}",
  ]
  s.frameworks = ["AVFoundation"]

  load 'nitrogen/generated/ios/VisionCameraTextRecognition+autolinking.rb'
  add_nitrogen_files(s)

  # Disambiguate Nitrogen shared C++ headers (e.g. Rect.hpp) from other pods when using static frameworks.
  s.pod_target_xcconfig = (s.pod_target_xcconfig || {}).merge({
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/nitrogen/generated/shared/c++" "${PODS_TARGET_SRCROOT}/nitrogen/generated/ios/c++"',
  })

  s.dependency 'GoogleMLKit/TextRecognition', '8.0.0'
  s.dependency 'VisionCamera'
  s.dependency 'React-jsi'
  s.dependency 'React-callinvoker'
  install_modules_dependencies(s)
end
