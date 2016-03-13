class CreateSitescanCommonAttributesOptions < ActiveRecord::Migration
  def change
    create_table :attributes_options do |t|

      t.timestamps null: false
    end
  end
end
