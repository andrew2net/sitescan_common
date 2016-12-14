module SitescanCommon
  class AttributeClassOption < ActiveRecord::Base
    self.table_name = :attribute_class_options
    belongs_to :attribute_class, class_name: SitescanCommon::AttributeClass
    has_many :attribute_options, class_name: SitescanCommon::AttributeOption,
      dependent: :delete_all
    has_and_belongs_to_many :attribute_lists,
      join_table: 'attribute_class_options_attribute_lists',
      class_name: SitescanCommon::AttributeList
    has_one :color, class_name: SitescanCommon::Color
    has_many :feature_source_attributes, as: :source_attribute,
      class_name: ::FeatureSourceAttribute
    has_many :feature_source_options, class_name: ::FeatureSourceOption
    validates :value, presence: true
    default_scope {order :value}

    # Return option.
    def filter_option
      { id: id, value: value }
    end

    def num_str_sortable
      if value.to_i.to_s == value
        [1, value.to_i]
      else
        [2, value]
      end
    end
  end
end
