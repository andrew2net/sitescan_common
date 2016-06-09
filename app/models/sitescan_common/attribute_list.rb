module SitescanCommon
  class AttributeList < ActiveRecord::Base
    self.table_name = :attribute_lists
    has_and_belongs_to_many :attribute_class_options,
      join_table: 'attribute_class_options_attribute_lists',
      class_name: 'SitescanCommon::AttributeClassOption'
    has_one :product_attribute, as: :value, dependent: :delete

    def value
      attribute_class_options.pluck(:value).join '/'
    end
  end
end
