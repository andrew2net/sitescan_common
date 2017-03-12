module SitescanCommon
  class DisabledProduct < ActiveRecord::Base
    self.table_name = :disabled_products
    belongs_to :product, inverse_of: :disabled_product

    after_save :product_reindex
    after_destroy :product_reindex

    protected
    def product_reindex
      product.reindex
    end
  end
end
