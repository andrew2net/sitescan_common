module SitescanCommon
  class SearchProduct < ActiveRecord::Base
    self.table_name = :search_products
    belongs_to :search_result
    has_one :product, through: :product_search_product
    has_one :product_search_product
    has_many :product_attributes, as: :attributable, dependent: :delete_all
    searchkick language: 'Russian'

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

    class << self
      def price_constraints(filter_params, product_ids)

        search_product_filtered_ids = SitescanCommon::ProductAttribute
          .filtered_search_product_ids filter_params

        # Get minimum and maximum price constraint.
        price_min_max = select('MIN(price) min_price, MAX(price) max_price')
          .joins(:product_search_product)
        price_min_max = price_min_max.where(product_search_products: {
          product_id: product_ids}) if product_ids
        price_min_max = price_min_max.where(search_products: {
          id: search_product_filtered_ids }) if search_product_filtered_ids

        price_min = '%g' % price_min_max[0].min_price if price_min_max[0].min_price
        price_max = '%g' % price_min_max[0].max_price if price_min_max[0].max_price
        [{id: 0, min: price_min, max: price_max}]
      end

    def min_price(filtered_ids)
      q = self
      if filtered_ids
        q = q.where id: filtered_ids
      end
      q.minimum(:price)
    end

    end
  end
end
