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

    scope :enabled, -> { includes(:disabled_product).where(disabled_products: {id: nil}) }
    scope :catalog, -> (categoru_ids) { enabled.joins(:categories).where(categories: {id: categoru_ids}).reorder(:name) }

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

    # Return image's url for first product's image or default image's url if the product doesn't have any image.
    def image_url
      img = product_images.reorder(:position).first
      if img then

        # We need to use class ProductImage without namespace for correct generating image path by Paperclip.
        SitescanCommon::ProductImage.find(img.id).attachment.url :medium
      else
        ActionController::Base.helpers.asset_path('sitescan_common/noimage.png')
      end
    end

    # Set the product if checked ia false.
    def set_disabled(checked)
      if checked
        disabled_product.destroy if disabled_product
      else
        create_disabled_product unless disabled_product
      end
    end

    # Return hash for product block in catalog category.
    def self.catalog_hash(category_ids)
      self.catalog(category_ids).map do |p|
        {
            name: p.name,
            img_src: p.image_url,
            price: p.search_products.minimum(:price),
            attrs: p.product_attributes.catalog_hash}
      end
    end

  end
end