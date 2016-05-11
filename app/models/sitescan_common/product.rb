module SitescanCommon

  # Public: Product model
  #
  # name - The product's name.
  class Product < ActiveRecord::Base
    self.table_name = :products
    has_and_belongs_to_many :categories
    has_one :disabled_product, dependent: :delete
    has_many :search_products, through: :product_search_products
    has_many :product_search_products, dependent: :destroy
    has_many :product_attributes, as: :attributable, dependent: :delete_all
    has_many :product_images, -> { order(position: :asc) }

    scope :not_disabled, ->{
      joins('LEFT OUTER JOIN disabled_products dp ON dp.product_id=products.id')
      .where(dp: {id: nil}) }
    scope :in_categories, -> (category_ids) {joins(:categories)
      .where(categories: {id: category_ids}).not_disabled}
    scope :catalog, -> (category_ids) {
      select('products.id, products.name, products.path')
      .includes(:product_images, :search_products,
    product_attributes: [:attribute_class, :value])
      .in_categories(category_ids).reorder(:name) }

    # Public: Move the product from one category tp another.
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

    # Return product data for prodact's page.
    def product_data(options)
      images = product_images.map do |img|
        {
          medium: {src: img.attachment.url(:medium)},
          thumb: {src: img.attachment.url(:thumb)}
        }
      end
      price = search_products
        .select('AVG(price) average, MIN(price) minimum, MAX(price) maximum')
      if options
        search_result_ids = nil
        options.each do |k,v|
          sr_ids = SitescanCommon::AttributeOption
            .where(attribute_class_option_id: v)
            .joins(:product_attribute).pluck 'product_attributes.attributable_id'
          if search_result_ids.blank?
            search_result_ids = sr_ids
          else
            search_result_ids = search_result_ids - sr_ids
          end
        end
        price = price.joins(:search_result)
          .where search_results: {id: search_result_ids}
      end

      # Product attribute ids linked to search result.
      search_result_ids = search_products
        .joins(search_result: :product_attributes)
        .pluck 'product_attributes.id'

      # Class option ids linked to search result.
      attr_cls_opt_ids = SitescanCommon::AttributeOption.joins(:product_attribute)
        .where(product_attributes: {id: search_result_ids})
        .pluck :attribute_class_option_id

      # Retrieve the product's attributes linked to search result.
      search_attrs = SitescanCommon::AttributeClass
        .select(:id, :name, :unit, :widget_id)
        .joins(%{ JOIN attribute_classes_categories acc
          ON acc.attribute_class_id=attribute_classes.id })
        .where(attribute_classes: {depend_link: true},
          acc: {category_id: categories.ids}).map do |attr|
          attr_name = [attr.name]
          attr_name << attr.unit unless attr.unit.blank?
        options = attr.attribute_class_options.select(:id, :value)
          .where(attribute_class_options: {id: attr_cls_opt_ids})
          .sort_by(&:num_str_sortable)
        {id: attr.id, name: attr_name, widget: attr.widget_id, options: options}
      end

      {
        name: name,
        images: images,
        price: {
          average: price[0].average.round,
          minimum: price[0].minimum.round,
          maximum: price[0].maximum.round
        },
        search_attrs: search_attrs
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

    class << self

      # Return hash for product block in catalog category.
      #
      # category_ids - Array of category ids.
      # filter_params - filter parameters.
      #
      # Return hash of filtered products data.
      def catalog_hash(category_ids, filter_params)
        search_result_filtered_ids = SitescanCommon::ProductAttribute
          .filtered_search_result_ids filter_params
        catalog(category_ids).filter(filter_params).map do |p|
          {
              name: p.name,
              path: p.path,
              img_src: p.image_url,
              price: p.search_products.min_price(search_result_filtered_ids),
              attrs: p.product_attributes.catalog_hash
          }
        end
      end

      # Return filter conditions for catalog products.
      #
      # filter_params - filter parametrs.
      #
      # Return conditions.
      def filter(filter_params)
        if filter_params.empty?
          all
        else
          sql = self
          if filter_params[:o]
            SitescanCommon::AttributeClass.joins(:attribute_class_options)
              .where(attribute_class_options: { id: filter_params[:o] })
              .each do |ac|
              opt_ids = ac.attribute_class_options.where(id: filter_params[:o]).ids
              product_ids = case ac.type_id
                            when 3
                              SitescanCommon::ProductAttribute
                                .filter_options opt_ids
                            when 5
                              SitescanCommon::ProductAttribute
                                .filter_lists opt_ids
                            end
              sql = sql.where id: product_ids
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
                num_condition << "pa.attributable_type='#{SitescanCommon::Product}'"
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
              sql = sql.where id: connection.select_values(num_query)
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
              sql = sql.where id: connection.select_values(bool_query)
            end
          end
          sql.all
        end
      end
    end
  end
end
