module SitescanCommon
  # Public: Attribute's value of product.
  #
  # value - The attribute's value.
  class AttributeValue < ActiveRecord::Base
    self.table_name = :attribute_values
    has_one :product_attribute, as: :value, dependent: :delete
  end
end