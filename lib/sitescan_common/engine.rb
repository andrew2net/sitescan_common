require 'paperclip'
require 'searchkick'
require 'acts_as_list'
require 'awesome_nested_set'

module SitescanCommon
  class Engine < ::Rails::Engine
    isolate_namespace SitescanCommon
  end
end
