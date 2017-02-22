module SitescanCommon
  # Public: The Category model.
  #
  # name - The name of the category.
  class Category < ActiveRecord::Base
    self.table_name = :categories
    acts_as_nested_set
    has_many :key_words, dependent: :delete_all #, class_name: KeyWord
    has_and_belongs_to_many :products #, class_name: 'SitescanCommon::Product'
    has_and_belongs_to_many :attribute_classes
      # class_name: 'SitescanCommon::AttributeClass'

    paperclip_opts = {
      styles: {thumb: '100x100'},
      default_url: Proc.new{ActionController::Base.helpers
        .asset_path('sitescan_common/noimage.png')
    }}

    if Rails.env.production?
      paperclip_opts.merge! storage: :s3,
        s3_region: 'us-east-1',
        s3_storage_class: {
          thumb: :REDUCED_REDUNDANCY
        },
        s3_credentials: "#{Rails.root}/config/s3.yml",
        path: 'category_images/:id/:style.:extension'
    end
    has_attached_file :image, paperclip_opts
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
        .map {|ac| ac.hash_attributable(product_id, SitescanCommon::Product.to_s)}
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
      result = Product
        .catalog_products(filter_params, self_and_descendants.ids)
      result
    end

    def breadcrumbs(bc=[])
      if bc.blank?
        bc << name
      else
        bc.unshift({ name: name, path: path })
      end
      cat = self
      until cat.root?
        cat = cat.parent
        bc.unshift({ name: cat.name, path: cat.path })
      end
      bc
    end

    # Return filter options.
    def filter
      AttributeClass.filter self_and_descendants.ids
    end

    # Return filter's attributes constraints.
    #
    # filter_params - set filter sttributes.
    #
    # Return array of hashes of attribute's constraints.
    def filter_constraints(filter_params)
      self.class.constraints filter_params, self_and_descendants.ids
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

      def constraints(filter_params, category_ids = nil)
        product_ids = Product
          .filtered_ids filter_params, category_ids

        price_constraints = SearchProduct
          .price_constraints filter_params, product_ids

        # Retrieve searchable number attribute's constraints.
        n_attrs = AttributeClass.searchable
          .select('attribute_classes.id, MIN(value) min, MAX(value) max')
          .joins(:product_attributes)
          .joins(%{ JOIN attribute_numbers an ON an.id=product_attributes.value_id
          AND product_attributes.value_type='#{SitescanCommon::AttributeNumber}'})
          .where(product_attributes: {attributable_type: SitescanCommon::Product})
          .group('attribute_classes.id')

        n_attrs = n_attrs.where product_attributes: {
          attributable_id: product_ids} if product_ids
        n_attrs = n_attrs.attrs_in_categories(category_ids) if category_ids

        number_constraints = n_attrs
          .map{|ac| {id: ac.id, min: '%g' % ac.min, max: '%g' % ac.max}}

        b_attrs = AttributeClass.where(type_id: 4).searchable
        b_attrs = b_attrs.attrs_in_categories(category_ids) if category_ids
        boolean_constraints = b_attrs.map do |ac|

          # Remove boolean option of current attribute class from the filter
          # to check if there are products with the options
          if filter_params[:b] and not (filter_params[:b] & [ac.id]).empty?
            f_params = filter_params.clone
            f_params[:b] = f_params[:b] - [ac.id]
            fp_ids = Product.filtered_ids f_params, category_ids
          elsif not fp_ids
            fp_ids = Product.filtered_ids filter_params, category_ids
          end
          pa = ac.product_attributes
            .where(attributable_type: SitescanCommon::Product)
          pa = pa.where(attributable_id: fp_ids) if fp_ids
          {id: ac.id, disabled: pa.ids.blank? }
        end

        # Retrieve searchable option and list attribute's constraints.
        o_attrs = AttributeClass.searchable.where(type_id: [3, 5])
        o_attrs = o_attrs.attrs_in_categories(category_ids) if category_ids
        option_constraints = o_attrs.map do |ac|

          # Remove options of current attribute class from the filter to check
          # if there are products with the options
          if filter_params[:o] and
              not (filter_params[:o] & ac.attribute_class_option_ids).empty?
            f_params = filter_params.clone
            f_params[:o] = f_params[:o] - ac.attribute_class_option_ids
            fp_ids = Product.filtered_ids f_params, category_ids
          elsif not fp_ids
            fp_ids = Product.filtered_ids filter_params, category_ids
          end
          sp = SearchProduct.joins(:product_search_product)
          sp = sp.where(product_search_products: {product_id: fp_ids}) if fp_ids
          sp_ids = sp.ids

          ao = if ac.type_id == 3 then AttributeOption
               else
                 AttributeList
                   .joins(%{JOIN attribute_class_options_attribute_lists col
                      ON col.attribute_list_id=attribute_lists.id})
               end
          condition = %{product_attributes.attributable_type=:pt fp
              OR product_attributes.attributable_type=:st
              AND ( product_attributes.attributable_id IN (:sr) OR :sr_nil )}
          params = {pt: SitescanCommon::Product,
               st: SitescanCommon::SearchProduct, sr: sp_ids,
               sr_nil: sp_ids.nil?}
          if fp_ids
            condition.sub!(/fp/, 'AND product_attributes.attributable_id IN (:fp)')
            params[:fp] = fp_ids
          else condition.sub!(/fp/, '') end
          ao = ao.distinct.joins(:product_attribute)
            .where(product_attributes: {attribute_class_id: ac.id})
            .where(condition, params).pluck :attribute_class_option_id

          {id: ac.id, options: ac.attribute_class_options.where.not(id: ao).ids}
        end
        price_constraints + number_constraints + boolean_constraints +
          option_constraints
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
