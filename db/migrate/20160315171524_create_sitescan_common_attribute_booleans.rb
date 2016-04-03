class CreateSitescanCommonAttributeBooleans < ActiveRecord::Migration
  def change
    create_table :attribute_booleans do |t|
      t.boolean :value

      t.timestamps null: false
    end
  end
end
