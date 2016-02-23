module SitescanCommon
  class SearchProduct < ActiveRecord::Base
    self.table_name = :search_products
    belongs_to :search_result
    has_one :product, through: :product_search_product
    has_one :product_search_product
    searchkick language: 'Russian'
    # scope :linked_products, ->(product_id) { select('search_products.id, name, price, search_results.link')
    #                                              .joins(:search_result, :product_search_product)
    #                                              .where(product_search_products: {product_id: product_id}) }

    def search_data
      {name: name}
    end

    def grid_data
      {name: name, price: price, link: search_result.link}
    end
  end
end