module SitescanCommon
  class AttributeNumber < ActiveRecord::Base
    self.table_name = :attribute_numbers
    has_one :product_attribute, as: :value, dependent: :delete,
      class_name: SitescanCommon::ProductAttribute
  end
end
