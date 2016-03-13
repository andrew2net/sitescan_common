module SitescanCommon
  class SearchProduct < ActiveRecord::Base
    self.table_name = :search_products
    belongs_to :search_result
    has_one :product, through: :product_search_product
    has_one :product_search_product
    searchkick language: 'Russian'

    scope :min_price, ->{select('MIN(price) AS min_price')}

    def search_data
      {name: name}
    end

    def grid_data
      {id: id, name: name, price: price, link: search_result.link}
    end
  end
end