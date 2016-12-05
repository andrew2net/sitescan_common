module SitescanCommon
  class AttributeBoolean < ActiveRecord::Base
    self.table_name = :attribute_booleans
    has_one :product_attribute, as: :value, dependent: :delete
      # class_name: SitescanCommon::ProductAttribute
  end
end
