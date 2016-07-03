module SitescanCommon
  # Product page scanning errors.
  #
  # type_id: 1 - page error, 2 - name error, 3 - price error.
  class SearchProductError < ActiveRecord::Base
    self.table_name = :search_product_errors

    belongs_to :search_result

    validates :type_id, uniqueness: { scope: :search_result_id }
  end
end
