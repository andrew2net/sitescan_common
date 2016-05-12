module SitescanCommon
  # Public: The Category model.
  #
  # name - The name of the category.
  class Category < ActiveRecord::Base
    self.table_name = :categories
    acts_as_nested_set
    has_many :key_words, dependent: :delete_all
    has_and_belongs_to_many :products
    has_and_belongs_to_many :attribute_classes
    has_attached_file :image, styles: { thumb: '100x100' },
                      default_url: ActionController::Base.helpers
      .asset_path('sitescan_common/noimage.png')
    validates_attachment_content_type :image, content_type: /\Aimage\/.*\Z/

    scope :popular, -> { where(show_on_main: true).order(:lft) }

    # Return the category's children for admin interface.
    #
    # id - The category's id.
    # with_products - If true include products.
    #
    # Return hash {id: child's id, parent: parent's id or # if no parent,
    #   text: child's name, type: product or nil,
    #   children: true if has children, img_name: category's image name,
    #   img_src: image's url,
    #   img_type: image's content type}.
    def self.get_category_with_children(id, with_products)
      if id == '#'
        categories = self.roots.order('lft').all
      else
        category = self.find(id)
        # categories = category.children.order('lft').all
        categories = self.where(parent_id: category.id).order :lft
      end

      data = categories.map do |cat|

        has_children = !cat.children.empty?
        if !has_children and with_products
          has_children = !cat.products.empty?
        end

        {
            id: cat.id.to_s,
            parent: cat.parent_id.nil? ? '#' : cat.parent_id.to_s,
            text: cat.name,
            children: has_children,
            show_on_main: cat.show_on_main,
            # path: cat.path,
            img_name: (cat.image_file_name or 'noimage'),
            img_src: cat.image.url(:thumb),
            img_type: (cat.image_content_type or 'image/png')
        }
      end

      if with_products and category
        category.products.reorder(:name).each do |p|
          data << {id: 'p' + p.id.to_s, parent: category.id, text: p.name,
                   type: :product, state: {checked: !p.disabled_product}}
        end
      end
      data
    end

    # Return hash of attributes for the product in the category.
    def attrs_product_to_set(product_id)
      AttributeClass.attrs_to_set(id, false, false)
        .map { |ac| ac.hash_attributable(product_id, SitescanCommon::Product.to_s) }
    end

    # Return hash of attributes for the product's image in the category.
    def attrs_image_to_set(image)
      AttributeClass.attrs_to_set(id, false, true)
        .map { |ac| ac.hash_attributable(image.id, image.class.to_s) }
    end

    # Return hash of attributes for the product's link in the category.
    def attrs_link_to_set(prod_link)
      AttributeClass.attrs_to_set(id, true, false)
        .map { |ac| ac.hash_link_attrs(prod_link.id, prod_link.class.to_s) }
    end

    # Return hash of category's data for main page.
    def data
      {name: name, path: path, img_src: image.url(:thumb)}
    end

    # Return hash data of category with products for catalog page.
    def catalog filter_params
      prods = SitescanCommon::Product
        .catalog_hash(self_and_descendants.ids, filter_params)
      {
        category: name,
        subcategories: descendants.select(:name, :path),
        products: prods
      }
    end

    # Return filter options.
    def filter
      filter_attributes = SitescanCommon::AttributeClass.searchable.weight_order
        .attrs_in_categories(self_and_descendants.ids)
        .map do |ac|
      # filter_attributes = attribute_classes.searchable.weight_order.map do |ac|
        name_unit = [ac.name]
        name_unit << ac.unit unless ac.unit.blank?
        {id: ac.id, name: name_unit, type: ac.type_id, options: ac.filter_options}
      end
      [{id: 0, name: [ 'Цена', 'руб.' ], type: 1}] + filter_attributes
    end

    # Return filter's attributes constraints.
    #
    # filter_params - set filter sttributes.
    #
    # Return array of hashes of attribute's constraints.
    def filter_constraints(filter_params)
      category_products = SitescanCommon::Product
        .in_categories(self_and_descendants.ids)

      filtered_products = category_products.filter filter_params

      search_product_filtered_ids = SitescanCommon::ProductAttribute
        .filtered_search_product_ids filter_params

      # Get minimum and maximum price constraint.
      price_min_max = filtered_products
        .select('MIN(price) min_price, MAX(price) max_price')
        .joins(:search_products)
      price_min_max = price_min_max.where(search_products: {
        search_result_id: search_product_filtered_ids
      }) if search_product_filtered_ids
      price_min = '%g' % price_min_max[0].min_price if price_min_max[0].min_price
      price_max = '%g' % price_min_max[0].max_price if price_min_max[0].max_price
      constraints = [{id: 0, min: price_min, max: price_max}]

      # Retrieve searchable number attribute's constraints.
      number_constraints = SitescanCommon::AttributeClass
        .attrs_in_categories(self_and_descendants.ids).searchable
        .select('attribute_classes.id, MIN(value) min, MAX(value) max')
        .joins(:product_attributes)
        .joins(%{ JOIN attribute_numbers an ON an.id=product_attributes.value_id
        AND product_attributes.value_type='#{SitescanCommon::AttributeNumber}'})
        .where(product_attributes: {attributable_id: filtered_products.ids,
          attributable_type: SitescanCommon::Product})
        .group('attribute_classes.id')
        .map{|ac| {id: ac.id, min: '%g' % ac.min, max: '%g' % ac.max}}

      boolean_constraints = SitescanCommon::AttributeClass.where(type_id: 4)
        .attrs_in_categories(self_and_descendants.ids).searchable.map do |ac|
        f_params = filter_params.clone
        f_params[:b] = f_params[:b] - [ac.id] if f_params[:b]
        fp_ids = category_products.filter(f_params).ids
        pa = ac.product_attributes
          .where(attributable_id: fp_ids, attributable_type: SitescanCommon::Product)
          .ids
        {id: ac.id, disabled: pa.blank? }
      end

      # Retrieve searchable option and list attribute's constraints.
      option_constraints = SitescanCommon::AttributeClass
        .attrs_in_categories(self_and_descendants.ids)
        .searchable.where(type_id: [3, 5]).map do |ac|
        f_params = filter_params.clone
        f_params[:o] = f_params[:o] - ac.attribute_class_options.ids if f_params[:o]
        fp_ids = category_products.filter(f_params).ids
        sp_ids = SitescanCommon::SearchProduct.joins(:product_search_product)
          .where(product_search_products: {product_id: fp_ids}).ids
          # .pluck :search_result_id

        ao = if ac.type_id == 3
               SitescanCommon::AttributeOption
             else
               SitescanCommon::AttributeList
                 .joins(%{JOIN attribute_class_options_attribute_lists col
            ON col.attribute_list_id=attribute_lists.id})
             end
        ao = ao.distinct.joins(:product_attribute)
          .where(product_attributes: {attribute_class_id: ac.id})
          .where(%{product_attributes.attributable_type=:pt
            AND product_attributes.attributable_id IN (:fp) OR
            product_attributes.attributable_type=:st
            AND ( product_attributes.attributable_id IN (:sr) OR :sr_nil )},
            {pt: SitescanCommon::Product, fp: fp_ids,
             st: SitescanCommon::SearchProduct, sr: sp_ids,
             sr_nil: sp_ids.nil?}).pluck :attribute_class_option_id

        {id: ac.id, options: ac.attribute_class_options.where.not(id: ao).ids}
      end
      constraints + number_constraints + boolean_constraints + option_constraints
    end

    # Return the category's image attributes.
    def image_attrs
      {
          img_name: (image_file_name or 'noimage'),
          img_src: image.url(:thumb),
          img_type: (image_content_type or 'image/png')
      }
    end

    # Generate path from name of the category.
    def path_generate
      I18n.locale = :ru
      self.path = ActiveSupport::Inflector.transliterate(name).downcase
        .parameterize.underscore
      save
      path
    end

    class << self

      # Find category by id or product_id and return.
      #
      # id - If prefixed by 'p' then find category by product_id,
      # in other case find by category's id.
      #
      # Returns the instance of the Category.
      def get_by_cat_prod_id(id)
        if id =~ /^p/
          product_id = id.sub(/^p/, '')
          get_by_product_id product_id
        else
          self.find id
        end
      end

      def get_by_product_id(product_id)
        self.joins(:products).where(products: {id: product_id}).first
      end

      def save_image(id, image)
        category = self.find id
        category.image = image
        category.save
        category.image_attrs
      end
    end
  end
end
