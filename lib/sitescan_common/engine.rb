require 'paperclip'
require 'searchkick'

module SitescanCommon
  class Engine < ::Rails::Engine
    isolate_namespace SitescanCommon
  end
end
