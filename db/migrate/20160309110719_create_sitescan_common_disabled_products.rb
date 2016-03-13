class CreateSitescanCommonDisabledProducts < ActiveRecord::Migration
  def change
    create_table :disabled_products do |t|
      t.references :product

      t.timestamps null: false
    end
  end
end
