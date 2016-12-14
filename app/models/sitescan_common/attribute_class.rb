module SitescanCommon
  # Attribute class model.
  #
  # name      - Attribute name.
  # type_id   - Attribute type (value: 1, range: 2, options: 3).
  # widget_id - Widget to display attribute
  #  (no widget: 0, memory size: 1, color: 2).
  # depend    - True if product's link depend on the attribute class.
  # attribute_class_group - The attribute class group.
  # weight    - The weight value of the attribute class inside the attribute
  # group.
  class AttributeClass < ActiveRecord::Base
    TYPE_NUMBER = 1
    TYPE_RANGE = 2
    TYPE_OPTION = 3
    TYPE_BOOLEAN = 4
    TYPE_LIST_OPTS = 5
    TYPE_STRING = 6
    self.table_name = :attribute_classes
    has_many :attribute_class_options, dependent: :delete_all,
      class_name: SitescanCommon::AttributeClassOption
    has_and_belongs_to_many :categories #, class_name: 'SitescanCommon::Category'
    belongs_to :attribute_class_group,
      class_name: SitescanCommon::AttributeClassGroup
    has_many :product_attributes, dependent: :restrict_with_error
      # class_name: SitescanCommon::ProductAttribute
    has_many :feature_source_attributes, as: :source_attribute,
      class_name: ::FeatureSourceAttribute
    validates :name, presence: true

    scope :grid, -> { includes(:categories, :attribute_class_options)
      .reorder(:weight) }

    scope :weight_order, -> {
      joins(%{ LEFT OUTER JOIN attribute_class_groups g
            ON g.id=attribute_classes.attribute_class_group_id })
          .reorder('g.weight, attribute_classes.weight')
    }

    scope :searchable, -> { where(searchable: true)}

    # Select attribute classes related to the category. Order the result by weight.
    #
    # category_id - The category's id.
    # link        - True if need select link related attributes.
    # image       - True if need select image related attributes.
    #
    # Return ActiveRecord::Relation.
    scope :attrs_to_set, ->(category_id, link, image) {
      joins(:categories, :attribute_class_group).includes(:product_attributes)
          .where(%{ categories.id=:category_id and (:image or depend_link=:link)
              and (:link or depend_image=:image) },
          {category_id: category_id, link: link, image: image}).weight_order
    }

    # Types of attributes.
    @@types = {'1': 'Значение', '2': 'Диапазон значений',
               '3': 'Опция из списка', '5': 'Список опций',
               '6': 'Строка', '4': 'Булево'}
    @@widgets = {'0': 'Heт', '1': 'Цвет', '2': 'Бренд', '3': 'Тип'}

    def type
      @@types[self.type_id.to_s.to_sym]
    end

    def widget
      @@widgets[self.widget_id.to_s.to_sym]
    end

    # Move the attribute class between groups and set order place.
    #
    # old_weight - The old weight.
    # new_group  - The new group.
    #
    # Returns nothing.
    def move(new_weight, new_group)
      if attribute_class_group_id != new_group

        # Reorder previous group.
        reorder_weights
        update attribute_class_group_id: new_group
      end
      reorder_weights new_weight
    end

    # Return attribute hash for attributes grid in admin panel.
    #
    # cat_prod_id - The ID of the product's category.
    #
    # Returns hash:
    #  :id        - The ID of the attribute class.
    #  :_checked  - True if the attribute class related to the product category.
    #  :name      - The name of the attribute class.
    #  :unit      - The unit of the attribute class.
    #  :type_id   - The ID of the attribute class type.
    #  :type      - The string name of the attribute class type.
    #  :widget_id - ID of widget.
    #  :widget    - The string name of the widget.
    #  :depend    - String 'true' or 'false'
    #  :options   - The array of the attribute's options.
    def attribute_hash(cat_prod_id)
      checked = false
      if cat_prod_id
        category = Category.get_by_cat_prod_id cat_prod_id
        checked = categories.exists? category.id
      end
      {
          id: id,
          _checked: checked,
          name: name,
          unit: unit,
          type_id: type_id.to_s,
          type: type,
          group: false,
          widget_id: widget_id.to_s,
          widget: widget,
          depend_link: depend_link,
          depend_image: depend_image,
          show_in_catalog: show_in_catalog,
          searchable: searchable,
          weight: weight,
          options: attribute_class_options.select(:id, :value),
      }
    end

    # Return attributes for product description or products's images.
    def hash_attributable(attributable_id, attributable_type)
      attr = {id: id, name: name, type: type_id, unit: unit,
              group: attribute_class_group.name}
      attr[:_value] = hash_value attributable_id,
        attributable_type unless type_id == 5

      # If attribute type is option or list of options.
      if type_id == TYPE_OPTION or type_id == TYPE_LIST_OPTS
        options = attribute_class_options.select(:id, :value)

        # Map options if attribute type is list of options.
        options = options.map do |opt|
          {
            id: opt.id,
            value: opt.value,
            _checked: hash_value(attributable_id, attributable_type, opt)
          }
        end if type_id == TYPE_LIST_OPTS

        attr[:options] = options
      end
      attr
    end

    # Return attributes for product's links.
    def hash_link_attrs(attributable_id, attributable_type)
      attr = {id: id}
      attr[:_value] = hash_value attributable_id, attributable_type
      attr
    end

    # Return the product's attribute set value.
    def hash_value(attributable_id, attributable_type, option = nil)
      pa = product_attributes.where(attributable_id: attributable_id,
                                    attributable_type: attributable_type).first
      case type_id
        when TYPE_NUMBER, TYPE_STRING
          if pa and pa.value
            pa.value.value
          else
            nil
          end
        when TYPE_RANGE
          if pa
            {from: pa.value.from, to: pa.value.to}
          else
            {from: nil, to: nil}
          end
        when TYPE_OPTION
          if pa then
            pa.value.attribute_class_option_id
          else
            nil
          end
        when TYPE_BOOLEAN
          if pa
            pa.value.value.to_s
          else
            nil
          end
        when TYPE_LIST_OPTS
          if pa
            v = pa.value.attribute_class_options.where(id: option.id)
            not v.empty?
          else
            nil
          end
      end
    end

    # Return filter item.
    def filter_options(ids)
      case type_id
      when TYPE_OPTION, TYPE_LIST_OPTS
        attribute_class_options.where(id: ids).sort_by(&:num_str_sortable)
          .map { |opt| opt.filter_option }
      end
    end

    def update(attributes, options = [])
      # if attributes[:type_id]
      AttributeClass.transaction do
        old_type_id = type_id
        result = super(attributes)
        # new_type_id = attributes[:type_id].to_i
        change_type(old_type_id, options)
        result
      end
    end

    class << self
      def types
        @@types
      end

      def wigets
        @@widgets
      end

      def widgets
        widgets = @@widgets.clone
        widgets.delete :'0'
        w = widgets.map do |k, v|
          options = self.joins(:attribute_class_options).where(widget_id: k.to_s)
          case k
          when :'1' # Color widget
            options = options.joins(%{ LEFT JOIN colors c ON
            c.attribute_class_option_id=attribute_class_options.id })
              .select(%{attribute_class_options.id,
            attribute_class_options.value AS name, c.value AS _value})
          end
          { id: k, name: v, options: options }
        end
        w
      end

      def attrs_in_categories(category_ids)
        sql = %{SELECT attribute_class_id FROM attribute_classes_categories
        WHERE category_id IN (:category_ids)}
        query = sanitize_sql_array [sql, category_ids: category_ids]
        attr_ids = connection.select_values query
        where(id: attr_ids)
      end

      def filter(category_ids = nil)

        # Select options ids for which there are products in the category.
        sql = %{SELECT DISTINCT attribute_class_option_id
        FROM attribute_options ao
        JOIN product_attributes pa ON ao.id=pa.value_id
        AND pa.value_type=:option_type
        LEFT JOIN search_products sp ON pa.attributable_id=sp.id
        AND pa.attributable_type=:search_type
        LEFT JOIN product_search_products psp ON sp.id=psp.search_product_id
        JOIN categories_products cp ON pa.attributable_id=cp.product_id
        OR psp.product_id=cp.product_id
        }
        sql = sql + "WHERE cp.category_id IN (:category_ids)" if category_ids
        sql = sql + %{UNION SELECT DISTINCT attribute_class_option_id
        FROM attribute_class_options_attribute_lists al
        JOIN product_attributes pa ON al.attribute_list_id=pa.value_id
        AND pa.value_type=:list_type
        LEFT JOIN search_products sp ON pa.attributable_id=sp.id
        AND pa.attributable_type=:search_type
        LEFT JOIN product_search_products psp ON sp.id=psp.search_product_id
        JOIN categories_products cp ON pa.attributable_id=cp.product_id
        OR psp.product_id=cp.product_id
        }
        query_params = {
          option_type: SitescanCommon::AttributeOption,
          list_type: SitescanCommon::AttributeList,
          product_type: SitescanCommon::Product,
          search_type: SitescanCommon::SearchProduct,
        }

        attrs = searchable.weight_order

        if category_ids
          sql = sql + "WHERE cp.category_id IN (:category_ids)"
          query_params[:category_ids] = category_ids
          attrs = attrs.attrs_in_categories(category_ids)
        end
        query = ActiveRecord::Base.send :sanitize_sql_array, [sql, query_params]
        option_ids = ActiveRecord::Base.connection.select_values query

        filter_attributes = attrs.map do |ac|
          name_unit = [ac.name]
          name_unit << ac.unit unless ac.unit.blank?
          {id: ac.id, name: name_unit, type: ac.type_id,
           options: ac.filter_options(option_ids)}
        end
        [{id: 0, name: [ 'Price', '$' ], type: 1}] + filter_attributes
      end
    end

    private

    # Change attribute's type. All product's attributes will convert to new type.
    #
    # new_type_id - The new type's id.
    # options - Array of options.
    def change_type(old_type_id, options)
      option_ids = []
      case type_id
        when TYPE_NUMBER
          change_product_attribute_types do |product_attribute|
            value = if old_type_id == TYPE_RANGE then
                      product_attribute.value.from
                    else
                      product_attribute.value.value
                    end
            SitescanCommon::AttributeNumber.create value: value
          end unless old_type_id == type_id
        when TYPE_RANGE
          change_product_attribute_types do |product_attribute|
            values = product_attribute.value.value.to_s.split ' - '
            SitescanCommon::AttributeRange.create from: values[0], to: values[1]
          end unless old_type_id == type_id
        when TYPE_OPTION, TYPE_LIST_OPTS
          change_product_attribute_types do |product_attribute|
            values = product_attribute.value.value.to_s.split '/'
            option = nil
            option_ids = []
            values.each do |v|
              option = SitescanCommon::AttributeClassOption
                .find_by attribute_class_id: id, value: v
              unless option
                option = AttributeClassOption.create attribute_class_id: id,
                  value:v
              end
              option_ids |= [option.id]
            end
            if type_id == TYPE_OPTION
              SitescanCommon::AttributeOption
                .create attribute_class_option_id: option.id
            else
              al = SitescanCommon::AttributeList.create
              al.attribute_class_options << option
              al
            end
          end unless old_type_id == type_id
        when TYPE_BOOLEAN
          change_product_attribute_types do |product_attribute|
            SitescanCommon::AttributeBoolean
              .create value: product_attribute.value.value
          end unless old_type_id == type_id
        when TYPE_STRING
          change_product_attribute_types do |product_attribute|
            SitescanCommon::AttributeString
              .create value: product_attribute.value.value
          end unless old_type_id == type_id
      end

      if type_id == TYPE_OPTION or type_id == TYPE_LIST_OPTS

        # Update option if it exist or create new in other case.
        options.each do |option|
          opt = SitescanCommon::AttributeClassOption
            .find_or_create_by id: option[:id], attribute_class_id: id
          opt.update value: option[:value]
          option_ids << opt.id
        end

        # Remove options which are not post to server.
        self.attribute_class_option_ids = option_ids unless old_type_id == type_id
      end
    end

    # Cycle through product's attributes to change type of values.
    def change_product_attribute_types
      product_attributes.each do |product_attribute|
        value = yield product_attribute
        product_attribute.value.delete
        value.product_attribute = product_attribute
      end
    end

    # Recalculate weights in current group. If new weight not set,
    # then current attribute wont not include.
    #
    # new_weight  - The new weight value for current attribute (default: nil).
    #
    # Examples
    #
    #  reorder_weights(3)
    #
    #  reorder_weights
    #
    # Returns nothing.
    def reorder_weights(new_weight = nil)
      update weight: new_weight
      w = 1
      self.class.where(attribute_class_group_id: attribute_class_group_id)
        .where.not(id: id).reorder(:weight).each do |attr|
        w = w + 1 if w == new_weight
        attr.update weight: w
        w = w + 1
      end
    end
  end
end
