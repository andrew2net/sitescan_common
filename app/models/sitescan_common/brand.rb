module SitescanCommon
  class Brand < ActiveRecord::Base
    self.table_name = :brands
    belongs_to :attribute_class_option

    paperclip_opts = {
      styles: {thumb: '200x100'},
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
        path: 'brand_images/:id/:style.:extension'
    end
    has_attached_file :logo, paperclip_opts
    validates_attachment_content_type :logo, content_type: /\Aimage\/.*\Z/

  end
end
