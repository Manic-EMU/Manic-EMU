Pod::Spec.new do |s|
  s.name             = 'BlankSlate'
  s.version          = '0.7.1'
  s.summary          = 'A drop-in UIView extension for showing empty datasets whenever the view has no content to display.'

s.description      = <<-DESC
It will work automatically, by just conforming to BlankSlate.DataSource, and returning the data you want to show. The reloadData() call will be observed so the empty dataset will be configured whenever needed.
                       DESC

  s.homepage         = 'https://github.com/liam-i/BlankSlate'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Liam' => 'liam_i@163.com' }
  s.source           = { :git => 'https://github.com/liam-i/BlankSlate.git', :tag => s.version.to_s }
#  s.documentation_url = 'https://liam-i.github.io/BlankSlate/main/documentation/blankslate'
  s.screenshots  = 'https://raw.githubusercontent.com/wiki/liam-i/BlankSlate/Screenshots/1.png'
  s.social_media_url   = "https://liam-i.github.io"

  # 1.12.0: Ensure developers won't hit CocoaPods/CocoaPods#11402 with the resource bundle for the privacy manifest.
  # 1.13.0: visionOS is recognized as a platform.
  s.cocoapods_version = '>= 1.13.0'

  s.ios.deployment_target = '12.0'
  s.tvos.deployment_target = '12.0'
  s.visionos.deployment_target = "1.1"

  s.swift_versions = ['5.0']

  s.source_files = 'Sources/**/*'
  
  s.resource_bundles = {'BlankSlate' => ['Sources/PrivacyInfo.xcprivacy']}
end
