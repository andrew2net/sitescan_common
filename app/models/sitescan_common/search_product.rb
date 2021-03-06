module SitescanCommon
  class SearchProduct < ActiveRecord::Base
    self.table_name = :search_products
    belongs_to :search_result
    has_one :product, through: :product_search_product
    has_one :product_search_product, dependent: :delete,
      class_name: SitescanCommon::ProductSearchProduct
    has_many :product_attributes, as: :attributable, dependent: :destroy,
      class_name: SitescanCommon::ProductAttribute

    searchkick searchable: [:name]

    after_save :product_reindex
    after_destroy :product_reindex

    scope :select_fields, -> {
      select('search_products.id, link, name, price').joins(:search_result)
    }
    scope :by_domain, ->(domain_id) { select_fields
      .where(search_results: { search_result_domain_id: domain_id })
    }

    def search_data
      arhived = search_result.search_product_errors.where(type_id: 4).count > 0
      has_errors = search_result.search_product_errors.where.not(type_id: 4)
        .count > 0
      {
        name: name,
        arhived: arhived,
        has_errors: has_errors
      }
    end

    def grid_data
      {
        id: id,
        name: name,
        price: price,
        link: search_result.link
      }
    end

    protected
    def product_reindex
      product_search_product.product.reindex if product_search_product
    end

    # class << self
      # def price_constraints(filter_params, product_ids)
      #
      #   search_product_filtered_ids = SitescanCommon::ProductAttribute
      #     .filtered_search_product_ids filter_params
      #
      #   # Get minimum and maximum price constraint.
      #   price_min_max = select('MIN(price) min_price, MAX(price) max_price')
      #     .joins(:product_search_product)
      #   price_min_max = price_min_max.where(product_search_products: {
      #     product_id: product_ids}) if product_ids
      #     price_min_max = price_min_max.where(search_products: {
      #       id: search_product_filtered_ids }) if search_product_filtered_ids
      #
      #       price_min = '%g' % price_min_max[0].min_price if price_min_max[0].min_price
      #       price_max = '%g' % price_min_max[0].max_price if price_min_max[0].max_price
      #       [{id: 0, min: price_min, max: price_max}]
      # end

      # def min_price(filtered_ids)
      #   q = self
      #   if filtered_ids
      #     q = q.where id: filtered_ids
      #   end
      #   q.minimum(:price)
      # end

    # end
  end
end
