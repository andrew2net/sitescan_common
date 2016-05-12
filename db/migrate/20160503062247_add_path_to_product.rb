class AddPathToProduct < ActiveRecord::Migration
  def change
    add_column :products, :path, :string
    add_index :products, :path, unique: true
  end
end
