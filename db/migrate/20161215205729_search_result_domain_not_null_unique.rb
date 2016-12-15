class SearchResultDomainNotNullUnique < ActiveRecord::Migration
  def change
    SitescanCommon::SearchResultDomain.where(domain: nil).each do |d|
      d.search_results.delete_all
      d.destroy
    end
    unique_ids = SitescanCommon::SearchResultDomain.group(:domain)
      .pluck 'min(search_result_domains.id)'
    SitescanCommon::SearchResultDomain.where.not(id: unique_ids).delete_all
    change_column_null :search_result_domains, :domain, false
    add_index :search_result_domains, :domain, unique: true
  end
end
