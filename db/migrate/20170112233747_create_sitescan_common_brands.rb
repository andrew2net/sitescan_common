class CreateSitescanCommonBrands < ActiveRecord::Migration
  def change
    create_table :brands do |t|
      t.references :attribute_class_option, index: true, foreign_key: true,
        null: false

      t.timestamps null: false
    end
    reversible do |dir|
      dir.up do
        add_attachment :brands, :logo
      end
      dir.down do
        remove_attachment :brands, :logo
      end
    end
  end
end
