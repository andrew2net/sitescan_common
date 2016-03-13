module SitescanCommon
  class DisabledProduct < ActiveRecord::Base
    self.table_name = :disabled_products
    belongs_to :product
  end
end
