module SitescanCommon
  # Public: Attribute's option of product.
  class AttributeOption < ActiveRecord::Base
    self.table_name = :attribute_options
    belongs_to :attribute_class_option
    has_one :product_attribute, as: :value, dependent: :delete

    def value
      attribute_class_option.value
    end
  end
end