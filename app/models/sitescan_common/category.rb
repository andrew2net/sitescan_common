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
                      default_url: ActionController::Base.helpers.asset_path('noimage.png')
    validates_attachment_content_type :image, content_type: /\Aimage\/.*\Z/

    def self.get_category_with_childs(id)
      if id == '#'
        categories = self.roots.order('lft').select('id, parent_id, name, image_file_name, image_content_type').all
      else
        category = self.find(id)
        categories = category.children.order('lft').select('id, parent_id, name, image_file_name, image_content_type').all
      end

      data = categories.map do |cat|

        has_children = !cat.children.empty?
        if !has_children and params[:products]
          has_children = !cat.products.empty?
        end

        {
            id: cat.id.to_s,
            parent: cat.parent_id.nil? ? '#' : cat.parent_id.to_s,
            text: cat.name,
            children: has_children,
            img_name: (cat.image_file_name or 'noimage.png'),
            img_src: cat.image.url(:thumb),
            img_type: (cat.image_content_type or 'image/png')
        }
      end

      if params[:products] and category
        category.products.each do |p|
          data << {id: 'p' + p.id.to_s, parent: category.id, text: p.name, type: :product}
        end
      end
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