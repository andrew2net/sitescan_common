module SitescanCommon
  class AttributeBoolean < ActiveRecord::Base
    self.table_name = :attribute_booleans
    has_one :product_attribute, as: :value, dependent: :destroy
    # class_name: SitescanCommon::ProductAttribute

    after_save :product_reindex

    protected
    def product_reindex
      product_attribute.product_reindex if product_attribute
    end
  end
end
