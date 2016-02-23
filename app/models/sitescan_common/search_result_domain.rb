module SitescanCommon
# Public: Search Result Domain model.
#
# status_id - new: 1, ignoring: 2, scanning: 3
  class SearchResultDomain < ActiveRecord::Base
    self.table_name = :search_result_domains
    has_many :search_results, dependent: :restrict_with_error
    has_many :search_attribute_paths, dependent: :delete_all
    has_one :fetch_ext_resource, dependent: :delete

    scope :search_domains, -> { select('search_result_domains.id, search_result_domains.domain')
                                    .where(status_id: 3).reorder(:domain) }
  end
end