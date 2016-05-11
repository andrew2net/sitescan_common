module SitescanCommon
  class ProductImage < ActiveRecord::Base
    self.table_name = :product_images
    belongs_to :product
    has_many :product_attributes, as: :attributable, dependent: :delete_all
    acts_as_list scope: :product
    has_attached_file :attachment, styles: {medium: '200x200', thumb: '50x50'}
    validates_attachment_content_type :attachment, content_type: /\Aimage\/.*\Z/
    scope :p_images, ->(product_id) { where(product_id: product_id) }

    def self.img_urls(product_id)
      images = p_images product_id
      images.map do |img|
        {
            id: img.id,
            position: img.position,
            name: img.attachment_file_name,
            img_type: img.attachment_content_type,
            src: img.attachment.url(:medium),
            attrs: img.attrs_to_set
        }
      end
    end

    def attrs_to_set
      category = Category.get_by_product_id product_id
      category.attrs_image_to_set self
    end

    def self.create_image(id, image)
      product_image = self.new product_id: id
      product_image.attachment = image
      product_image.save
      { id: product_image.id, attrs: product_image.attrs_to_set }
    end

  end
end
