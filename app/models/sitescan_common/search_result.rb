module SitescanCommon
# Public: Search Result model.
  class SearchResult < ActiveRecord::Base
    self.table_name = :search_results
    has_and_belongs_to_many :key_words
    has_many :categories, through: :key_words
    has_many :search_product_errors, dependent: :destroy
    has_one :search_product, dependent: :destroy
    belongs_to :search_result_domain

    validates :link, uniqueness: true

    scope :toScan, -> { joins(:search_result_domain)
      .where search_result_domains: {status_id: 3} }

    scope :errors, ->(type) { select(%{
    search_result_domains.id, search_results.id as sr_id,
                                     search_results.link AS domain
    }).joins(:search_product_errors, :search_result_domain)
      .where(search_product_errors: {type_id: type}).reorder :link }

    scope :in_catalog, -> { joins(:search_result_domain, :search_product)
      .where(search_products: {id: ProductSearchProduct.pluck(:search_product_id)})
      .where.not(id: SearchProductError.pluck(:search_result_id))}

    scope :linked_products, ->(product_id) {
      joins(search_product: [:product_search_product])
          .where(product_search_products: {product_id: product_id})
    }

    # def search_result_content_with_initialize
    #   search_result_content_without_initialize || build_search_result_content
    # end

    def search_result_domain
      if s = super
        s
      else
        domain = SitescanCommon::SearchResultDomain
          .find_or_create_by domain: URI(link).host
        # search_result_domain= domain
        update search_result_domain_id: domain.id
        super
      end
    end

    def add_err(type_id)
      unless search_product_errors.exists? type_id: type_id
        search_product_errors.create type_id: type_id
      end
    end

    def remove_err(type_id)
      spe = search_product_errors.find_by type_id: type_id
      spe.destroy if spe
    end

    def set_error(type_id, error = false)
      if error
        add_err type_id
      else
        remove_err type_id
      end
    end

    # alias_method_chain :search_result_content, :initialize
    # alias_method_chain :search_result_domain, :initialize
  end
end
