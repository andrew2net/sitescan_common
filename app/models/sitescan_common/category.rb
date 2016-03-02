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
                      default_url: ActionController::Base.helpers.asset_path('sitescan_common/noimage.png')
    validates_attachment_content_type :image, content_type: /\Aimage\/.*\Z/

    # Return the category's children.
    #
    # id - The category's id.
    # with_products - If true include products.
    #
    # Return hash {id: child's id, parent: parent's id or # if no parent, text: child's name, type: product or nil,
    #   children: true if has children, img_name: category's image name, img_src: image's url,
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
        category.products.each do |p|
          data << {id: 'p' + p.id.to_s, parent: category.id, text: p.name, type: :product}
        end
      end
      data
    end

    def attrs_product_to_set(product_id)
      AttributeClass.attrs_to_set(id, false, false).map { |ac| ac.hash_attributable(product_id, 'Product') }
    end

    def attrs_image_to_set(image)
      AttributeClass.attrs_to_set(id, false, true).map { |ac| ac.hash_attributable(image.id, image.class.to_s) }
    end

    def attrs_link_to_set(prod_link)
      AttributeClass.attrs_to_set(id, true, false).map { |ac| ac.hash_link_attrs(prod_link.id, prod_link.class.to_s) }
    end

    class << self

      # Public: Find category by id or product_id and return.
      #
      # id - If prefixed by 'p' then find category by product_id, in other case find by category's id.
      #
      # Returns the instance of the Category.
      def get_by_cat_prod_id(id)
        if id =~ /^p/
          product_id = id.sub /^p/, ''
          get_by_product_id product_id
        else
          self.find id
        end
      end

      def get_by_product_id(product_id)
        self.joins(:products).where(products: {id: product_id}).first
      end
    end
  end
end