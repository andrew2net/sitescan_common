module SitescanCommon
  # Public: Attribute's option of product.
  class AttributeOption < ActiveRecord::Base
    self.table_name = :attribute_options
    belongs_to :attribute_class_option
    has_one :product_attribute, as: :value

    after_save :product_reindex

    def value
      attribute_class_option.value
    end

    protected
    def product_reindex
      product_attribute.product_reindex if product_attribute
    end
  end
end
