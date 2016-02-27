class AddShowOnMainToCategory < ActiveRecord::Migration
  def change
    add_column :categories, :show_on_main, :boolean
  end
end
