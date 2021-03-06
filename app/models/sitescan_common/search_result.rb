module SitescanCommon
  # Public: Search Result model.
  class SearchResult < ActiveRecord::Base
    self.table_name = :search_results
    has_and_belongs_to_many :key_words
    has_many :categories, through: :key_words
    has_many :search_product_errors, dependent: :destroy,
      class_name: SitescanCommon::SearchProductError
    has_one :search_product, dependent: :destroy
    belongs_to :search_result_domain

    validates :link, uniqueness: true

    STATUS_NEW = 1
    STATUS_IGNORE = 2
    STATUS_SCAN = 3

    # Select results with search status (3).
    scope :toScan, -> { where %{search_result_domain_id = ANY(ARRAY(SELECT id
      FROM search_result_domains where status_id=3))}}

    scope :errors, ->(type) { select(%{
    search_result_domains.id, search_results.id as sr_id, link, title
    }).joins(:search_product_errors, :search_result_domain)
      .where(search_product_errors: {type_id: type}).reorder :link }

    # Select results which are linked to products and have no errors.
    scope :in_catalog, -> {
      where(%{search_results.id=ANY(ARRAY(SELECT search_result_id
      FROM search_products sp
      JOIN product_search_products psp ON psp.search_product_id=sp.id))})
    }

    scope :select_fields, -> { select(:id, :link, :title) }

    scope :linked_products, ->(product_id) {
      joins(search_product: [:product_search_product])
          .where(product_search_products: {product_id: product_id})
    }

    scope :by_domain, ->(domain_id) {where(search_result_domain_id: domain_id)}

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
        self.search_result_domain_id = domain.id
        save
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

    # Create search product if it does not exist or update if exist.
    #
    # args - Hash {:name, :price}
    def create_or_update_search_product(args)
      return false unless args[:name] and args[:price]
      if search_product
        search_product.update args
      else
        create_search_product args
      end
    end

    # Update link of the instance. If link with new value exist and tied
    # to product then remove the instance, if exist but not tied then remove
    # existed link.
    #
    # url - new value of link.
    #
    # Return true if link updated, false if instance removed.
    def update_link
      # if save
      #   true
      # else
        sr_clone = SitescanCommon::SearchResult.includes(:search_product)
          .references(:search_product).where.not(id: id).find_by_link link
        if sr_clone
          if search_product and search_product.product
            sr_clone.destroy
            true
          elsif search_product and sr_clone.search_product and
            sr_clone.search_product.product or
            not search_product and sr_clone.search_product
            destroy
            false
          else
            sr_clone.destroy
            true
          end
        end
        true
      # end
    end

    # alias_method_chain :search_result_content, :initialize
    # alias_method_chain :search_result_domain, :initialize
  end
end
