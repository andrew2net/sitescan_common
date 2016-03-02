require 'paperclip'
require 'searchkick'
require 'acts_as_list'
require 'awesome_nested_set'

module SitescanCommon
  class Engine < ::Rails::Engine
    isolate_namespace SitescanCommon
    initializer 'sitescan_common.assets.precompile' do |app|
      app.config.assets.precompile += %w(*.png)
    end

    config.generators do |g|
      g.test_framework      :rspec,        :fixture => false
      g.fixture_replacement :factory_girl, :dir => 'spec/factories'
      g.assets false
      g.helper false
    end
  end
end
