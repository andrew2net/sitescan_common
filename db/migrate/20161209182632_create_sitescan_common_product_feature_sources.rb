class CreateSitescanCommonProductFeatureSources < ActiveRecord::Migration
  def change
    create_table :product_feature_sources do |t|
      t.string :url
      t.references :product, index: true, foreign_key: true, null: false

      t.timestamps null: false
    end
  end
end
