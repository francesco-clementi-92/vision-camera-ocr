require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  # Must match nitro.json ios.iosModuleName for Swift C++ interop.
  s.name         = "VisionCameraTextRecognition"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => 15.5, :visionos => 1.0 }
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

  s.dependency 'GoogleMLKit/TextRecognition', '8.0.0'
  s.dependency 'VisionCamera'
  s.dependency 'React-jsi'
  s.dependency 'React-callinvoker'
  install_modules_dependencies(s)

  current_pod_target_xcconfig = s.attributes_hash['pod_target_xcconfig'] || {}
  current_header_search_paths = Array(current_pod_target_xcconfig['HEADER_SEARCH_PATHS'])
  s.pod_target_xcconfig = current_pod_target_xcconfig.merge({
    'HEADER_SEARCH_PATHS' => current_header_search_paths + [
      '"${PODS_TARGET_SRCROOT}/nitrogen/generated/shared/c++"',
      '"${PODS_TARGET_SRCROOT}/nitrogen/generated/ios"',
      '"${PODS_TARGET_SRCROOT}/nitrogen/generated/ios/c++"',
    ],
  })
end
