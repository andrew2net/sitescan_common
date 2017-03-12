module SitescanCommon

  # Public: Product model
  #
  # name - The product's name.
  class Product < ActiveRecord::Base
    searchkick
    self.table_name = :products
    has_and_belongs_to_many :categories #, class_name: SitescanCommon::Category
    has_one :disabled_product, dependent: :delete,
      class_name: SitescanCommon::DisabledProduct
    has_many :search_products, through: :product_search_products
    has_many :product_search_products, dependent: :destroy
      # class_name: SitescanCommon::ProductSearchProduct
    has_many :product_attributes, as: :attributable, dependent: :delete_all
    has_many :product_images, -> { order(position: :asc) },
      class_name: SitescanCommon::ProductImage
    has_one :admin_product, dependent: :delete
    has_one :admin, through: :admin_product #, class_name: Admin
    has_one :product_feature_source, dependent: :delete

    scope :not_disabled, ->{
      joins('LEFT OUTER JOIN disabled_products dp ON dp.product_id=products.id')
        .where(dp: {id: nil}).where("(path='') IS FALSE") }
    scope :in_categories, -> (category_ids) {joins(:categories)
      .where(categories: {id: category_ids}).not_disabled}
    scope :catalog, -> (category_ids) {
      select('products.id, products.name, products.path')
        .includes(:product_images, :search_products,
      product_attributes: [:attribute_class, :value])
        .in_categories(category_ids).reorder(:name) }
      scope :with_admin, -> {select(
      %{
        admins.id, admins.first_name, products.name, products.created_at,
        (SELECT COUNT(*) FROM product_search_products psp
          WHERE psp.product_id=products.id) AS links_count
      })
        .joins('LEFT JOIN admin_products ap ON ap.product_id=products.id')
        .joins('LEFT JOIN admins ON admins.id=ap.admin_id')
        .order('products.created_at')}

    def search_data

      # Parents category's ids.
      cat_ids = categories.inject([]){|a, c| a + c.self_and_ancestors.map(&:id)}

      # Prices values.
      prices = search_products.all.distinct.pluck :price

      indices = { name: name, categories_id: cat_ids, 0 => prices }

      attr_cls_ids = categories.joins(
        'JOIN attribute_classes_categories acc ON acc.category_id=categories.id')
        .distinct.pluck(:attribute_class_id)
      AttributeClass.where(id: attr_cls_ids).searchable.each do |ac|
        case ac.type_id
        when AttributeClass::TYPE_NUMBER, AttributeClass::TYPE_BOOLEAN
          val = product_attributes.where(attribute_class_id: ac.id).take
          indices[ac.id] = val.value.value if val
        when AttributeClass::TYPE_OPTION

          if ac.depend_link

            # Search products attribute's ids.
            opt_ids = search_products.joins(
              %{JOIN product_attributes pa ON pa.attributable_id=search_products.id
              AND pa.attributable_type='SitescanCommon::SearchProduct'})
              .joins('JOIN attribute_options ao ON ao.id=pa.value_id')
              .where(pa: {value_type: AttributeOption, attribute_class_id: ac.id})
              .distinct.pluck :attribute_class_option_id
          else

            # Option attribute's id.
            opt = product_attributes.where(attribute_class_id: ac.id).take
            opt_ids = opt.value.attribute_class_option_id if opt
          end

          indices[ac.id] = opt_ids unless opt_ids.blank?
        when AttributeClass::TYPE_LIST_OPTS

          # Lists options attribute's ids.
          lopt_ids = product_attributes.joins(
            %{ JOIN attribute_class_options_attribute_lists acl
            ON acl.attribute_list_id=product_attributes.value_id })
            .where(value_type: AttributeList, attribute_class_id: ac.id)
            .distinct.pluck :attribute_class_option_id
          indices[ac.id] = lopt_ids unless lopt_ids.blank?
        end
      end

      indices
    end

    # Move the product from one category tp another.
    #
    # old_category_id - Category's id from which the product is moved.
    # new_category_id - Category's id to which the product is moved.
    def change_category(old_category_id, new_category_id)
      old_category = SitescanCommon::Category.find old_category_id
      self.categories.delete old_category
      new_category = SitescanCommon::Category.find new_category_id
      self.categories << new_category
    end

    # Return image's url for first product's image or default image's url
    # if the product doesn't have any image.
    def image_url
      img = product_images.reorder(:position).first
      if img then
        # SitescanCommon::ProductImage.find(img.id)
        img.attachment.url :medium
      else
        ActionController::Base.helpers.asset_path('sitescan_common/noimage.png')
      end
    end

    # Return product data for product's page.
    def product_data(options)

      # Images urls.
      images = product_images.map do |img|
        {
          medium: {src: img.attachment.url(:medium)},
          thumb: {src: img.attachment.url(:thumb)}
        }
      end

      # Retrieve the category's attributes linked to search result.
      search_attrs = SitescanCommon::AttributeClass
        .select(:id, :name, :unit, :widget_id)
        .attrs_in_categories(categories.ids)
        .where(depend_link: true).weight_order.map do |attr|

        attr_name = [attr.name]
        attr_name << attr.unit unless attr.unit.blank?

        attr_options = attr.attribute_class_options.select(:id, :value)
        case attr.widget_id
        when 1
          attr_options = attr_options.select('colors.value AS clr').joins(:color)
        end

        {
          id: attr.id,
          name: attr_name,
          widget: attr.widget_id,
          options: attr_options.sort_by(&:num_str_sortable)
        }
      end

      # Generate breadcrubs.
      breadcrumbs = []
      category = categories.first
      brand = product_attributes.joins(:attribute_class)
        .where(attribute_classes: {widget_id: 2}).first

      breadcrumbs << {
        name: brand.value.attribute_class_option.value,
        path:category.path,
        options:brand.value.attribute_class_option_id
      } if brand

      # Retrieve links related to the product with their attributes.
      links = self.search_products.order(:price)
        .select('search_products.id, search_results.id sr_id, domain, price')
        .joins(search_result: :search_result_domain)
        .where.not(search_results: {
        id: SitescanCommon::SearchProductError.select(:search_result_id)
      }).map do |sp|
        attrs = sp.product_attributes.map do |pa|
          [pa.attribute_class_id, pa.value.attribute_class_option_id]
        end
        {
          id: sp.sr_id,
          domain: sp.domain,
          price: sp.price,
          attrs: attrs.to_h
        }
      end

      # Retrieve the product's attributes and groups of attributes.
      attr_groups = []
      attributes = product_attributes
        .joins(attribute_class: :attribute_class_group).includes(:value)
        .order('attribute_class_groups.weight, attribute_classes.weight')
        .map do |pa|
        attr_group = {
          id: pa.attribute_class.attribute_class_group.id,
          name: pa.attribute_class.attribute_class_group.name
        }
        attr_groups << attr_group unless attr_groups.index attr_group
        value = []
        value << case pa.attribute_class.type_id
                when 1
                  '%g' % pa.value.value
                when 4
                  if pa.value.value then 'Yes' else 'No' end
                else
                  pa.value.value
                end
        value << pa.attribute_class.unit unless pa.attribute_class.unit.blank?
        {
          group_id: pa.attribute_class.attribute_class_group.id,
          name: pa.attribute_class.name,
          value: value.join(' ')
        }
      end

      type = product_attributes.joins(:attribute_class)
        .where(attribute_classes: {widget_id: 3}).first
      product_name = [name]
      product_name.unshift type.value.value if type

      {
        breadcrumbs: category.breadcrumbs(breadcrumbs),
        name: product_name,
        images: images,
        search_attrs: search_attrs,
        links: links,
        attr_groups: attr_groups,
        attrs: attributes
      }
    end

    # Set the product if checked ia false.
    def set_disabled(checked)
      if checked
        disabled_product.destroy if disabled_product
      else
        create_disabled_product unless disabled_product
      end
    end

    # Create path based on paroduct's name.
    def path_generate
      I18n.locale = :ru
      self.path = ActiveSupport::Inflector.transliterate(name).downcase
        .parameterize.underscore
      save
      path
    end

    # Return data for the product's block in catalog.
    def catalog_hash(filtered_search_product_ids)
      {
        name: name,
        path: path,
        img_src: image_url,
        price: search_products.min_price(filtered_search_product_ids),
        attrs: product_attributes.catalog_hash
      }
    end

    class << self

      # Return data for product blocks in catalog category.
      #
      # category_ids - Array of category ids.
      # filter_params - filter parameters.
      #
      # Return filtered products data.
      def catalog_products(filter_params:, category_ids: nil)
        params = {
          order: {_score: :desc, name: :asc},
          fields: [:name],
          aggs: elastic_aggs(category_ids),
          body_options: {
            aggs: SitescanCommon::AttributeClass.elastic_stats(category_ids)
          },
          page: (filter_params[:page] or 1),
          per_page: 10,
          where: elastic_where(filter_params, category_ids)
        }

        # if product_ids = filtered_ids(filter_params, category_ids)
        #   params[:where] = {id: product_ids}
        # end

        text = (filter_params[:search] or '*')
        not_disabled.search(text, params)
      end

      # def filter(filter_params)
      #   if ids = filtered_ids(filter_params)
      #     where(products:{id: ids})
      #   else
      #     self
      #   end
      # end

      # Return filtered product ids.
      #
      # filter_params - filter parametrs hash.
      # category_ids - array of ids selected category and it's descendants.
      #
      # Return array.
      def filtered_ids(filter_params, category_ids = nil)
        product_ids = not_disabled.ids.map(&:to_s)
        if category_ids
          sql = %{SELECT product_id FROM categories_products
          WHERE category_id IN (:ids)}
          query = sanitize_sql_array [sql, {ids: category_ids}]
          p_ids = connection.select_values query
          product_ids = if product_ids then product_ids & p_ids else p_ids end
        end

        if filter_params[:o]
          SitescanCommon::AttributeClass.joins(:attribute_class_options)
            .where(attribute_class_options: { id: filter_params[:o] })
            .each do |ac|
            opt_ids = ac.attribute_class_options
              .where(id: filter_params[:o]).ids
            p_ids = case ac.type_id
                    when 3
                      SitescanCommon::ProductAttribute.filter_options opt_ids
                    when 5
                      SitescanCommon::ProductAttribute.filter_lists opt_ids
                    end
            product_ids = if product_ids then product_ids & p_ids else p_ids end
          end
        end

        if filter_params[:n]
          filter_params[:n].each do |key, value|
            num_condition = []

            # If key is 0 then it is price filter.
            if key == 0
              num_condition << 'price>=:min' if value[:min]
              num_condition << 'price<=:max' if value[:max]
              num_sql = %{SELECT DISTINCT product_id FROM search_products sp
                JOIN product_search_products psp ON psp.search_product_id=sp.id
                WHERE #{num_condition.join ' AND '}}
            else
              num_condition <<
              "pa.attributable_type='#{SitescanCommon::Product}'"
              num_condition << 'attribute_class_id=:attr_cls_id'
              num_condition << 'value>=:min' if value[:min]
              num_condition << 'value<=:max' if value[:max]
              num_sql = %{SELECT attributable_id FROM product_attributes pa
                JOIN attribute_numbers an ON pa.value_id=an.id
                AND pa.value_type='#{SitescanCommon::AttributeNumber.to_s}'
                WHERE #{num_condition.join ' AND '}}
            end
            num_query = sanitize_sql_array [num_sql,
                                            value.merge(attr_cls_id: key)]
            p_ids = connection.select_values(num_query)
            product_ids = if product_ids then product_ids & p_ids else p_ids end
          end
        end

        if filter_params[:b]
          filter_params[:b].each do |attr_id|
            bool_sql = %{SELECT attributable_id FROM product_attributes pa
              JOIN attribute_booleans ab ON ab.id=pa.value_id
              AND pa.value_type='#{SitescanCommon::AttributeBoolean.to_s}'
              WHERE attribute_class_id=:attr_id AND value=true
              AND pa.attributable_type='#{SitescanCommon::Product.to_s}'}
            bool_query = sanitize_sql_array [bool_sql, attr_id: attr_id]
            p_ids = connection.select_values(bool_query)
            product_ids = if product_ids then product_ids & p_ids else p_ids end
          end
        end
        product_ids
      end

      private
      def elastic_aggs(category_ids)
        [:categories_id] + SitescanCommon::AttributeClass
          .categories_attr_ids(type_ids: [
          SitescanCommon::AttributeClass::TYPE_OPTION,
          SitescanCommon::AttributeClass::TYPE_BOOLEAN,
          SitescanCommon::AttributeClass::TYPE_LIST_OPTS
        ], category_ids: category_ids).map(&:to_s)
      end

      # Create conditions from params.
      def elastic_where(filter_params, category_ids)
        conditions = {}
        conditions[:categories_id] = category_ids if category_ids
        SitescanCommon::AttributeClassOption.where(id: filter_params[:o])
          .each do |aco|
          case aco.attribute_class.type_id
          when AttributeClass::TYPE_OPTION
            unless conditions[aco.attribute_class.id]
              conditions[aco.attribute_class.id] = []
            end
            conditions[aco.attribute_class.id] << aco.id
          when AttributeClass::TYPE_LIST_OPTS
            unless conditions[aco.attribute_class.id]
              conditions[aco.attribute_class.id] = {all: []}
            end
            conditions[aco.attribute_class.id][:all] |= [aco.id]
          end
        end

        filter_params[:n].each do |key, val|
          conditions[key] = {}
          conditions[key][:gte] = val[:min] if val[:min]
          conditions[key][:lte] = val[:max] if val[:max]
        end if filter_params[:n]

        filter_params[:b].each do |key|
          conditions[key] = true
        end if filter_params[:b]
        conditions
      end

    end

  end
end
