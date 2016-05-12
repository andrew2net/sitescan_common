module SitescanCommon
  class SearchProduct < ActiveRecord::Base
    self.table_name = :search_products
    belongs_to :search_result
    has_one :product, through: :product_search_product
    has_one :product_search_product
    has_many :product_attributes, as: :attributable, dependent: :delete_all
    searchkick language: 'Russian'

    def self.min_price(filtered_ids)
      q = self
      if filtered_ids
        q = q.where search_result_id: filtered_ids
      end
      q.minimum(:price)
    end

    def search_data
      {name: name}
    end

    def grid_data
      {
        id: id,
        name: name,
        price: price,
        link: search_result.link
      }
    end
  end
end
