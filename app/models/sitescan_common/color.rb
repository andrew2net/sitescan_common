module SitescanCommon
  class Color < ActiveRecord::Base
    self.table_name = :colors
    belongs_to :attribute_class_option
  end
end
