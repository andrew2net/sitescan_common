module SitescanCommon
  # Attribute class model.
  #
  # name      - Attribute name.
  # type_id   - Attribute type (value: 1, range: 2, options: 3).
  # widget_id - Widget to display attribute
  #  (no widget: 0, color: 1, brand: 2).
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
    WIDGET_NO = 0
    WIDGET_COLOR = 1
    WIDGET_BRAND = 2
    WIDGET_TYPE = 3
    self.table_name = :attribute_classes
    has_many :attribute_class_options, dependent: :delete_all,
      class_name: SitescanCommon::AttributeClassOption
    has_and_belongs_to_many :categories #, class_name: 'SitescanCommon::Category'
    belongs_to :attribute_class_group,
      class_name: SitescanCommon::AttributeClassGroup
    has_many :product_attributes, dependent: :restrict_with_error
      # class_name: SitescanCommon::ProductAttribute

    if Rails.application.class.parent_name == 'SiteScan'
      has_many :feature_source_attributes, as: :source_attribute,
        class_name: ::FeatureSourceAttribute
    end

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
    @@types = {
      TYPE_NUMBER.to_s.to_sym => 'Значение',
      TYPE_RANGE.to_s.to_sym => 'Диапазон значений',
      TYPE_OPTION.to_s.to_sym => 'Опция из списка',
      TYPE_BOOLEAN.to_s.to_sym => 'Булево',
      TYPE_LIST_OPTS.to_s.to_sym => 'Список опций',
      TYPE_STRING.to_s.to_sym => 'Строка'
    }
    @@widgets = {
      WIDGET_NO.to_s.to_sym => 'Heт',
      WIDGET_COLOR.to_s.to_sym => 'Цвет',
      WIDGET_BRAND.to_s.to_sym => 'Бренд',
      WIDGET_TYPE.to_s.to_sym => 'Тип'
    }

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

      def widgets
        @@widgets
      end

      def widgets_options
        wc = @@widgets.clone
        wc.delete :'0'
        w = wc.map do |k, v|
          case k
          when WIDGET_COLOR.to_s.to_sym # Color widget
            options = self.includes(attribute_class_options: :color)
              .where(widget_id: k.to_s)
              .pluck('attribute_class_options.id',
                'attribute_class_options.value', 'colors.value')
          when WIDGET_BRAND.to_s.to_sym
            options = self.includes(attribute_class_options: :brand)
              .where(widget_id: k.to_s).inject([]) do |o, a|
              o + a.attribute_class_options.map do |b|
                [
                  b.id,
                  b.value,
                  (b.brand && b.brand.logo.url),
                  b.brand && b.brand.logo_file_name,
                  b.brand && b.brand.logo_content_type
                ]
              end
            end
          when WIDGET_TYPE.to_s.to_sym
            options = []
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

      # Return list of filters for categories.
      def filter(category_ids = nil)

        # # Select options ids for which there are products in the category.
        # sql = %{SELECT DISTINCT attribute_class_option_id
        # FROM attribute_options ao
        # JOIN product_attributes pa ON ao.id=pa.value_id
        # AND pa.value_type=:option_type
        # LEFT JOIN search_products sp ON pa.attributable_id=sp.id
        # AND pa.attributable_type=:search_type
        # LEFT JOIN product_search_products psp ON sp.id=psp.search_product_id
        # JOIN categories_products cp ON pa.attributable_id=cp.product_id
        # OR psp.product_id=cp.product_id
        # }
        # sql = sql + "WHERE cp.category_id IN (:category_ids)" if category_ids
        # sql = sql + %{UNION SELECT DISTINCT attribute_class_option_id
        # FROM attribute_class_options_attribute_lists al
        # JOIN product_attributes pa ON al.attribute_list_id=pa.value_id
        # AND pa.value_type=:list_type
        # LEFT JOIN search_products sp ON pa.attributable_id=sp.id
        # AND pa.attributable_type=:search_type
        # LEFT JOIN product_search_products psp ON sp.id=psp.search_product_id
        # JOIN categories_products cp ON pa.attributable_id=cp.product_id
        # OR psp.product_id=cp.product_id
        # }
        # query_params = {
        #   option_type: SitescanCommon::AttributeOption,
        #   list_type: SitescanCommon::AttributeList,
        #   product_type: SitescanCommon::Product,
        #   search_type: SitescanCommon::SearchProduct,
        # }
        #
        # attrs = searchable.weight_order
        #
        # if category_ids
        #   sql = sql + "WHERE cp.category_id IN (:category_ids)"
        #   query_params[:category_ids] = category_ids
        #   attrs = attrs.attrs_in_categories(category_ids)
        # end
        # query = ActiveRecord::Base.send :sanitize_sql_array, [sql, query_params]
        # option_ids = ActiveRecord::Base.connection.select_values query
        #
        # filter_attributes = attrs.map do |ac|
        #   name_unit = [ac.name]
        #   name_unit << ac.unit unless ac.unit.blank?
        #   {id: ac.id, name: name_unit, type: ac.type_id,
        #    options: ac.filter_options(option_ids)}
        # end

        params = { aggs: attr_aggs(category_ids) }
        params[:where] = { categories_id: category_ids } if category_ids
        aggs = SitescanCommon::Product.search(params).aggs
        attr_ids = if aggs then aggs.keys else [] end

        filter_attributes = self.weight_order.where(id: attr_ids).map do |a|
          name_unit = [a.name]
          name_unit << a.unit unless a.unit.blank?
          at = { id: a.id, name: name_unit, type: a.type_id }
          if [TYPE_OPTION, TYPE_LIST_OPTS].include? a.type_id
            opt_ids = aggs[a.id.to_s]['buckets'].map { |o| o['key'] }
            at[:options] = a.filter_options opt_ids
          end
          at
        end
        [{id: 0, name: [ 'Price', '$' ], type: 1}] + filter_attributes
      end

      # Create conditions from params.
      #
      # filter_params - number, boolean and options filter params
      # category_ids - array of categories ids
      # body - if true return conditions in elasctisearch format
      def elastic_where(filter_params:, category_ids:, body: false)

        conditions = if body then [{term: {enabled: :true}}]
                     else { enabled: true } end

        if category_ids
          if body then conditions << {terms: {category_ids: category_ids}}
          else conditions[:categories_id] = category_ids end
        end

        attrs_opts = {}
        attrs_list_opts = {}
        SitescanCommon::AttributeClassOption.where(id: filter_params[:o])
          .each do |aco|
          case aco.attribute_class.type_id
          when TYPE_OPTION
            unless attrs_opts[aco.attribute_class.id]
              attrs_opts[aco.attribute_class.id] = []
            end
            attrs_opts[aco.attribute_class.id] << aco.id
          when TYPE_LIST_OPTS
            unless attrs_list_opts[aco.attribute_class.id]
              attrs_list_opts[aco.attribute_class.id] = []
            end
            attrs_list_opts[aco.attribute_class.id] << aco.id
          end
        end

        attrs_opts.each do |attr, opts|
          if body then conditions << { terms: { attr => opts }}
          else conditions[attr] = opts end
        end

        attrs_list_opts.each do |attr, opts|
          if body then opts.each { |opt| conditions << { term: { attr => opt }}}
          else conditions[attr] = { all: opts } end
        end

        filter_params[:n].each do |key, val|
          if body
            range = { key => {} }
            range[key].merge!({from: val[:min], include_lower: true}) if val[:min]
            range[key].merge!({ to: val[:max], include_upper: true }) if val[:max]
            conditions << { range: range }
          else
            conditions[key] = {}
            conditions[key][:gte] = val[:min] if val[:min]
            conditions[key][:lte] = val[:max] if val[:max]
          end
        end if filter_params[:n]

        filter_params[:b].each do |key|
          if body then conditions << { term: { key => true }}
          else conditions[key] = true end
        end if filter_params[:b]
        conditions
      end

      def categories_attrs(type_ids: nil, category_ids:)
        attrs = self.joins( %{JOIN attribute_classes_categories acc
          ON acc.attribute_class_id=attribute_classes.id }).searchable
        attrs = attrs.where(type_id: type_ids) if type_ids
        attrs = attrs.where(acc: { category_id: category_ids }) if category_ids
        attrs.select(:id, :type_id)
      end

      # Return hash of attributes id's as keys and hahes for
      # elasticsearch stats query as vaues.
      #
      # category_ids - ids of categories
      # type_ids - attribute's type ids
      # stats - type of elasticsearch aggregation (stats, min, max)
      def elastic_stats(category_ids, type_ids: TYPE_NUMBER, stats: :stats)
        stats_hash(0, stats: stats).merge categories_attrs(
          category_ids: category_ids,
          type_ids: type_ids)
          .inject({}){ |h, attr| h.merge(stats_hash(attr.id, stats: stats))}
      end

      private
      def attr_aggs(category_ids)
        categories_attrs(category_ids: category_ids).map { |attr| attr.id.to_s }
      end

      # Return hash for elasticsearch stats query.
      #
      # attr_id - Attribute class id
      # stats - type of elasticsearch aggregation (stats, min, max)
      def stats_hash(attr_id, stats: )
        key = attr_id.to_s
        { key => { stats => { field: key }}}
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
          option_ids |= [opt.id]
        end

        # Remove options which are not post to server.
        self.attribute_class_option_ids = option_ids # unless old_type_id == type_id
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
