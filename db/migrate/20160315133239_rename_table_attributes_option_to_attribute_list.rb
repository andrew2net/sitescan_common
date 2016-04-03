class RenameTableAttributesOptionToAttributeList < ActiveRecord::Migration
  def change
    rename_table :attributes_options, :attribute_lists
    rename_table :attribute_class_options_attributes_options, :attribute_class_options_attribute_lists
    rename_column :attribute_class_options_attribute_lists, :attributes_option_id, :attribute_list_id
    rename_index :attribute_class_options_attribute_lists, :index_acoao_on_attribute_option_id, :index_acoao_on_attribute_list_id
  end
end
