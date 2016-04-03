class CreateAttributeClassOptionsAttributesOptions < ActiveRecord::Migration
  def change
    create_table :attribute_class_options_attributes_options, id: false do |t|
      t.belongs_to :attribute_class_option, index: {name: :index_acoao_on_attribute_class_option_id}
      t.belongs_to :attributes_options, index: {name: :index_acoao_on_attribute_option_id}
    end
  end
end
