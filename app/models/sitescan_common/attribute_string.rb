module SitescanCommon
  # String attribute of product.
  #
  # value - The attribute's value.
  class AttributeString < ActiveRecord::Base
    self.table_name = :attribute_strings
    has_one :product_attribute, as: :value, dependent: :delete
  end
end