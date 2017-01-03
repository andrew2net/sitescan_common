module SitescanCommon
# Public: Search Result Domain model.
#
# status_id - new: 1, ignoring: 2, scanning: 3
  class SearchResultDomain < ActiveRecord::Base
    self.table_name = :search_result_domains
    has_many :search_results, dependent: :restrict_with_error
    has_many :search_attribute_paths, dependent: :delete_all
    has_one :fetch_ext_resource, dependent: :delete

    scope :search_domains, -> { select('id, domain, params_wipe_pattern')
                                  .where(status_id: 3).reorder(:domain) }

    STATUS_NEW = 1
    STATUS_IGNORE = 2
    STATUS_SCAN = 3

    def self.domain_by_url(url)
      uri = URI url
      host = (uri.hostname or url)
      find_by domain: host
    end
  end
end
