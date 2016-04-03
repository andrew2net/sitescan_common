class CreateSitescanCommonAttributeNumbers < ActiveRecord::Migration
  def change
    create_table :attribute_numbers do |t|
      t.decimal :value, precision: 10, scale: 2

      t.timestamps null: false
    end
  end
end
