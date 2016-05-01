module SitescanCommon
  class AttributeClassOption < ActiveRecord::Base
    self.table_name = :attribute_class_options
    belongs_to :attribute_class
    has_many :attribute_options
    has_and_belongs_to_many :attribute_lists,
      join_table: 'attribute_class_options_attribute_lists',
      class_name: 'SitescanCommon::AttributeList'
    validates :value, presence: true
    default_scope {order :value}

    # Return option.
    def filter_option
      { id: id, value: value }
    end
  end
end
