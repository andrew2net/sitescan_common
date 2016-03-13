module SitescanCommon
  class AttributeClassOption < ActiveRecord::Base
    self.table_name = :attribute_class_options
    belongs_to :attribute_class
    has_many :attribute_options
    validates :value, presence: true
    default_scope {order :value}
  end
end