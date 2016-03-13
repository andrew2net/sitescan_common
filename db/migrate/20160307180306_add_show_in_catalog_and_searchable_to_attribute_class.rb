class AddShowInCatalogAndSearchableToAttributeClass < ActiveRecord::Migration
  def change
    add_column :attribute_classes, :show_in_catalog, :boolean
    add_column :attribute_classes, :searchable, :boolean
  end
end
