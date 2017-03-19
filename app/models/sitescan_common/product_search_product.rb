module SitescanCommon
  class ProductSearchProduct < ActiveRecord::Base
    self.table_name = :product_search_products
    belongs_to :product
    belongs_to :search_product
    validates :product_id, uniqueness: {scope: :search_product_id}

    after_save :product_reindex
    after_destroy :product_reindex

    protected
    def product_reindex
      product.reindex
    end
  end
end
