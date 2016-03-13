module SitescanCommon
  class AttributesOption < ActiveRecord::Base
    self.table_name = :attributes_options
    has_and_belongs_to_many :attribute_class_options
    has_one :product_attribute, as: :value, dependent: :delete
  end
end
