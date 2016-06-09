module SitescanCommon
  # Public: Product's attribute model
  class ProductAttribute < ActiveRecord::Base
    self.table_name = :product_attributes
    belongs_to :attributable, polymorphic: true
    belongs_to :value, polymorphic: true, dependent: :delete
    belongs_to :attribute_class

    # Select attributes to show in product block in catalog.
    scope :catalog, -> {joins(attribute_class: :attribute_class_group)
      .where(attribute_classes: {show_in_catalog: true})
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
          create_or_update_value SitescanCommon::AttributeRange,
            {from: _value[:from], to: _value[:to]}
        when 3
          create_or_update_value SitescanCommon::AttributeOption,
            {attribute_class_option_id: _value}
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
          val = case pa.attribute_class.type_id
                when 1
                  '%g' % pa.value.value
                else
                  pa.value.value
                end
          {name: pa.attribute_class.name, value: val, unit: pa.attribute_class.unit}
        end
      end

      # Return search product filtered ids for select minimal price.
      def filtered_search_product_ids(filter_params)

        # Select ids of attributes linked to search product.
        search_product_attribute = SitescanCommon::AttributeClass
          .where(depend_link: true)

        # Set condition to select product attributes related to search product.
        sql = where( attributable_type: SitescanCommon::SearchProduct )

        ids = nil

        # If the filter contains one or more options.
        if filter_params[:o]

          # Select classs attribute ids related to the filter options.
          sr_opt_attr_ids = search_product_attribute
            .joins(:attribute_class_options)
            .where(attribute_class_options: { id: filter_params[:o] }).ids

          # For each class attribute select product attribute ids.
          sr_opt_attr_ids.each do |attr_id|

            # Select options ids related to the class attribute.
            search_product_option_ids = SitescanCommon::AttributeClassOption
              .where(attribute_class_id: attr_id, id: filter_params[:o]).ids

            # Select Search products ids filtered by option or list of options.
            # Options which belong to same list type attribute conjuct with
            # OR logical condition.
            sr_opt_ids = sql.joins(%{ JOIN attribute_options ao
            ON ao.id=product_attributes.value_id
            AND value_type='#{ SitescanCommon::AttributeOption.to_s }' AND
            attribute_class_option_id IN (#{search_product_option_ids.join ','})})
              .pluck :attributable_id

            # Attributes conjuct with AND logical condition.
            ids = if ids then ids & sr_opt_ids else sr_opt_ids end
          end
        end

        # If filter has nubmer attributes.
        if filter_params[:n]
          filter_numbers = search_product_attribute.ids & filter_params[:n].keys
          filter_numbers.each do |key, value|
            unless key == 0
              num_condition = []
              num_condition << 'value>=:min' if value[:min]
              num_condition << 'value<=:max' if value[:max]
              num_condition << 'attribute_class_id=:attr_cls_id'
              sr_num_ids = sql.join( %{ JOIN attribute_numbers an
              ON an.id=product_attributes.value_id
              AND value_type='#{SitescanCommon::AttributeNumber.to_s}' } )
                .where(num_condition.join ' AND ', value.merge(attr_cls_id: key))
                .pluck :attributable_id
              ids = if ids
                      ids & sr_num_ids
                    else
                      sr_num_ids
                    end
            end
          end
        end
        ids
      end

      # Return filtered product's ids.
      def filter_options(attr_class_option_ids)
        sql = %{
        SELECT DISTINCT CASE WHEN attributable_type=:product THEN
          attributable_id ELSE product_id END AS p_id 
        FROM product_attributes pa
        JOIN attribute_options ao ON ao.id=pa.value_id 
        LEFT JOIN product_search_products psp
          ON psp.search_product_id=attributable_id
          AND pa.attributable_type=:search_product
        WHERE attributable_type IN (:product, :search_product)
        AND value_type=:attribute_options 
        AND ao.attribute_class_option_id IN (:attr_class_option_ids) 
        }
        query = sanitize_sql_array [sql,
                      {
                      product: SitescanCommon::Product,
                      search_product: SitescanCommon::SearchProduct,
                      attribute_options: SitescanCommon::AttributeOption,
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
