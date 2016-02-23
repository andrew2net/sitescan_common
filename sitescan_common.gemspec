$:.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'sitescan_common/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'sitescan_common'
  s.version     = SitescanCommon::VERSION
  s.authors     = ['andrew2net']
  s.email       = ['android.2net@gmail.com']
  s.homepage    = 'https://github.com/sitescan_common'
  s.summary     = 'Common modules fo site scan system.'
  s.description = 'Common modules fo site scan system.'
  s.license     = 'MIT'

  s.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.rdoc']
  s.test_files = Dir['test/**/*']

  s.add_dependency 'rails', '~> 4.2.1'
  s.add_dependency 'searchkick'
  s.add_dependency 'paperclip', '~> 4.3'

  s.add_development_dependency 'pg'
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'factory_girl_rails'
end
