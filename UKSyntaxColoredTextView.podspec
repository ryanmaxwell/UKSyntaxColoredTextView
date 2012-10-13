Pod::Spec.new do |s|
  s.name         = 'UKSyntaxColoredTextView'
  s.version      = '0.1'
  s.summary      = 'A view controller class that implements a text editor that performs "live" syntax coloring in an NSTextView'
  s.homepage     = 'http://github.com/ryanmaxwell/UKSyntaxColoredTextView'
  s.authors      = { 'Uli Kusterer' => 'contact@zathras.de', 'Ryan Maxwell' => 'ryanm@xwell.co.nz' }
  s.source       = { :git => 'https://github.com/ryanmaxwell/UKSyntaxColoredTextView.git' }
  s.platform     = :osx, '10.7'
  s.source_files = 'Classes/*.{h,m}'
  s.public_header_files = 'Classes/UKSyntaxColoredTextViewController.h'
  s.resources = 'SyntaxDefinition.plist', 'SyntaxColorDefaults.plist', 'Syntax Definitions/*.plist'
  s.requires_arc = true
end
