module SitescanCommon
  class SearchProduct < ActiveRecord::Base
    self.table_name = :search_products
    belongs_to :search_result
    has_one :product, through: :product_search_product
    has_one :product_search_product
    searchkick language: 'Russian'

    def self.min_price(filtered_ids)
      q = self
      unless filtered_ids.blank?
        q = q.where search_result_id: filtered_ids
      end
      q.minimum(:price)
    end

    def search_data
      {name: name}
    end

    def grid_data
      {id: id, name: name, price: price, link_id: search_result.id, link: search_result.link}
    end
  end
end
