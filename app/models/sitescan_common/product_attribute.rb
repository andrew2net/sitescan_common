module SitescanCommon
  # Public: Product's attribute model
  class ProductAttribute < ActiveRecord::Base
    self.table_name = :product_attributes
    belongs_to :attributable, polymorphic: true
    belongs_to :value, polymorphic: true, dependent: :delete
    belongs_to :attribute_class

    # Select attributes to show in product block in catalog.
    scope :catalog, -> {joins(attribute_class: :attribute_class_group).where(attribute_classes: {show_in_catalog: true})
      .reorder('attribute_class_groups.weight, attribute_classes.weight')}

    # Update attribute value.
    #
    # _value - attribute value.
    # type - type of attribute.
    def value_update(_value, type)
      if _value.blank?
        destroy
      else
        case type
        when 1
          create_or_update_value SitescanCommon::AttributeNumber, {value: _value}
        when 2
          create_or_update_value SitescanCommon::AttributeRange, {from: _value[:from], to: _value[:to]}
        when 3
          create_or_update_value SitescanCommon::AttributeOption, {attribute_class_option_id: _value}
        when 4
          create_or_update_value SitescanCommon::AttributeBoolean, {value: _value}
        when 6
          create_or_update_value SitescanCommon::AttributeString, {value: _value}
        end
      end
    end

    class << self

      # Return product's hash data for catalog.
      def catalog_hash
        catalog.map do |pa|
          {name: pa.attribute_class.name, value: pa.value.value, unit: pa.attribute_class.unit}
        end
      end

      # Return filtered product's ids.
      def filter_options(attr_class_option_ids)
        sql = %{
        SELECT DISTINCT CASE WHEN attributable_type=:product THEN attributable_id ELSE product_id END AS p_id 
        FROM product_attributes pa
        JOIN attribute_options ao ON ao.id=pa.value_id 
        LEFT JOIN search_products sp ON sp.search_result_id=pa.attributable_id
          AND pa.attributable_type=:search_result
        LEFT JOIN product_search_products psp ON psp.search_product_id=sp.id
        WHERE attributable_type IN (:product, :search_result)
        AND value_type=:attribute_options 
        AND ao.attribute_class_option_id IN (:attr_class_option_ids) 
        }
        query = sanitize_sql_array [sql,
                      {
                      product: SitescanCommon::Product.to_s,
                      search_result: SitescanCommon::SearchResult.to_s,
                      attribute_options: SitescanCommon::AttributeOption.to_s,
                      attribute_lists: SitescanCommon::AttributeList.to_s,
                      attr_class_option_ids: attr_class_option_ids
                    }]
        connection.select_values query
      end

      # Return product ids filtered by list type attributes.
      # Product pass the filter if it has all selected optios in list attributes.
      #
      # attr_class_option_ids - Array of selected attributes ids.
      #
      # Return array of filtered products ids.
      def filter_lists(attr_class_option_ids)
        # q = joins('JOIN attribute_lists al ON al.id=product_attributes.value_id')
        #   .joins('JOIN attribute_class_options_attribute_lists oal ON oal.attribute_list_id=al.id')
        #   .where(attributable_type: SitescanCommon::Product.to_s,
        #           value_type: SitescanCommon::AttributeList.to_s)
        # attr_class_option_ids.each do |opt_id|
        #   q = q.where attribute_class_option_id: opt_id
        # end
        # q.ids
        sql = %{
        SELECT attributable_id
        FROM product_attributes pa
        JOIN attribute_lists al ON al.id=pa.value_id AND pa.value_type=:attribute_lists
        JOIN attribute_class_options_attribute_lists oal ON oal.attribute_list_id=al.id
        WHERE attributable_type=:product AND value_type=:attribute_lists
        AND oal.attribute_class_option_id IN (:attr_class_option_ids)
        GROUP BY attributable_id
        HAVING COUNT(attributable_id)=:count
        }
        query = sanitize_sql_array [sql,
                      {
                      product: SitescanCommon::Product.to_s,
                      attribute_lists: SitescanCommon::AttributeList.to_s,
                      attr_class_option_ids: attr_class_option_ids,
                      count: attr_class_option_ids.size
                    }]
        connection.select_values query
      end
    end

    private
    def create_or_update_value(klass, value_hash)
      if value_id
        value = klass.find_or_create_by id: value_id
        value.update value_hash
      else
        value = klass.create value_hash
        value.product_attribute = self
      end
    end
  end
end
