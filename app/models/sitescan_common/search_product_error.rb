module SitescanCommon
  # Product page scanning errors.
  #
  # type_id: 1 - page error, 2 - name error, 3 - price error, 4 - arhived.
  class SearchProductError < ActiveRecord::Base
    self.table_name = :search_product_errors

    belongs_to :search_result

    validates :type_id, uniqueness: { scope: :search_result_id }

    after_commit :search_product_reindex

    private
    def search_product_reindex
      search_result.search_product.reindex if search_result.search_product
    end
  end
end
