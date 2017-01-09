module SitescanCommon
  # Public: Attribute's range of product.
  #
  # from - The start value of range.
  # to   - The end value of range.
  class AttributeRange < ActiveRecord::Base
    self.table_name = :attribute_ranges
    has_one :product_attribute, as: :value, dependent: :destroy

    def value
      value = from.to_s
      value << ' - ' + to.to_s if to
    end
  end
end
