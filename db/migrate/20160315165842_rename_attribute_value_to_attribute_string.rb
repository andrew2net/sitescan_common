class RenameAttributeValueToAttributeString < ActiveRecord::Migration
  def change
    rename_table :attribute_values, :attribute_strings
    reversible do |dir|
      dir.up do
        SitescanCommon::ProductAttribute.where(value_type: 'SitescanCommon::AttributeValue')
            .update_all(value_type: 'SitescanCommon::AttributeString')
      end
    end
  end
end
