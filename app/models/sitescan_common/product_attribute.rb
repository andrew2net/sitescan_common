module SitescanCommon
  # Public: Product's attribute model
  class ProductAttribute < ActiveRecord::Base
    self.table_name = :product_attributes
    belongs_to :attributable, polymorphic: true
    belongs_to :value, polymorphic: true, dependent: :delete

    def value_update(_value, type)
      unless _value
        destroy
      else
        case type
          when 1
            if value_id
              value = AttributeValue.find_or_create_by id: value_id
              value.update value: _value
            else
              value = AttributeValue.create value: _value
              value.product_attribute = self
            end
          when 2
            if value_id
              value = AttributeRange.find_or_create_by id: value_id
              value.update from: _value[:from], to: _value[:to]
            else
              value = AttributeRange.create from: _value[:from], to: _value[:to]
              value.product_attribute = self
            end
          when 3
            if value_id
              value = AttributeOption.find_or_create_by id: value_id
              value.update attribute_class_option_id: _value
            else
              value = AttributeOption.create attribute_class_option_id: _value
              value.product_attribute = self
            end
        end
      end
    end
  end
end