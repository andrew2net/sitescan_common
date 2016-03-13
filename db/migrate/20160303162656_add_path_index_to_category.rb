class AddPathIndexToCategory < ActiveRecord::Migration
  def change
    add_index :categories, :path, unique: true
  end
end
