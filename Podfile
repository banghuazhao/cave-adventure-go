# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'Cave Adventure Go' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  pod 'Localize-Swift', '~> 2.0'
  pod 'SwiftyButton'
  pod 'SnapKit', '~> 5.0.0'
  pod 'Then'
  pod 'Google-Mobile-Ads-SDK'
  
  # Pods for Cave Treasure Hunt

  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
      end
    end
  end


end
