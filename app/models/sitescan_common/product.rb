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

    scope :enabled, -> { joins('LEFT OUTER JOIN disabled_products dp ON dp.product_id=products.id')
      .where(dp: {id: nil}) }
    scope :catalog, -> (category_ids) { select('products.id, products.name').enabled.joins(:categories)
      .includes(:product_images, :search_products, product_attributes: [:attribute_class, :value])
      .where(categories: {id: category_ids}).reorder(:name) }

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

    class << self

      # Return hash for product block in catalog category.
      def catalog_hash(category_ids, filter_params)
        if filter_params[:o]
          opt_ids = filter_params[:o].split ','
          search_result_filtered = SitescanCommon::ProductAttribute
            .joins('JOIN attribute_options ao ON ao.id=product_attributes.value_id')
            .where( attributable_type: SitescanCommon::SearchResult.to_s,
                    value_type: SitescanCommon::AttributeOption.to_s,
                    ao: {attribute_class_option_id: opt_ids}
                  ).pluck :attributable_id
        end
        catalog(category_ids).filter(filter_params).map do |p|
          {
              name: p.name,
              img_src: p.image_url,
              price: p.search_products.min_price(search_result_filtered),
              attrs: p.product_attributes.catalog_hash
          }
        end
      end

      def filter(filter_params)
        if filter_params.empty?
          all
        else
          if filter_params[:o]
            opts = filter_params[:o].split ','
            sql = self
            SitescanCommon::AttributeClass.joins(:attribute_class_options)
              .where(attribute_class_options: { id: opts }).each do |ac|
              product_ids = case ac.type_id
                            when 3
                              SitescanCommon::ProductAttribute
                                .filter_options opts
                            when 5
                              SitescanCommon::ProductAttribute
                                .filter_lists opts
                            end
              sql = sql.where id: product_ids
            end
            sql.all
          end
        end
      end
    end
  end
end
