require 'paperclip'
require 'aws-sdk'
require 'searchkick'
require 'acts_as_list'
require 'awesome_nested_set'
require 'globalize'

module SitescanCommon
  class Engine < ::Rails::Engine
    isolate_namespace SitescanCommon

    # config.before_initialize do
    #   config.i18n.load_path += Dir["#{config.root}/config/locales/**/*.yml"]
    # end

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
