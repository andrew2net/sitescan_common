module SitescanCommon
  class Color < ActiveRecord::Base
    self.table_name = :colors
    belongs_to :attribute_class_options,
      class_name: SitescanCommon::AttributeClassOption
  end
end
