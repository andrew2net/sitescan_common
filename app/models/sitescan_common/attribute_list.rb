module SitescanCommon
  class AttributeList < ActiveRecord::Base
    self.table_name = :attribute_lists
    has_and_belongs_to_many :attribute_class_options,
      after_add: :product_reindex, after_remove: :product_reindex,
      join_table: 'attribute_class_options_attribute_lists'
      # class_name: SitescanCommon::AttributeClassOption
    has_one :product_attribute, as: :value
      # class_name: SitescanCommon::ProductAttribute

    def value
      attribute_class_options.pluck(:value).join '/'
    end

    protected
    def product_reindex(attribute_class_option)
      product_attribute.product_reindex if product_attribute
    end
  end
end
