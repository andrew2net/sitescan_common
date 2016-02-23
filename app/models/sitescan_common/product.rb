module SitescanCommon
  # Public: Product model
  #
  # name - The product's name.
  class Product < ActiveRecord::Base
    self.table_name = :products
    has_and_belongs_to_many :categories
    has_many :search_product, through: :product_search_products
    has_many :product_search_products, dependent: :destroy
    has_many :product_attributes, as: :attributable, dependent: :delete_all
    has_many :product_images, -> { order(position: :asc) }

    # Public: Move the product from one category tp another.
    #
    # old_category_id - Category's id from which the product is moved.
    # new_category_id - Category's id to which the product is moved.
    def change_category(old_category_id, new_category_id)
      old_category = Category.find old_category_id
      self.categories.delete old_category
      new_category = Category.find new_category_id
      self.categories << new_category
    end
  end
end