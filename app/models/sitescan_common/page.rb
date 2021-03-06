module SitescanCommon
  class Page < ActiveRecord::Base
    self.table_name = :pages
    validates :title, presence: true, length: {maximum: 255}
    validates :url, uniqueness: true
    validates :type_id, numericality: {only_integer: true, allow_blank: true}
    translates :title, :text, :keywords, :description

    TYPES = {page: 1, articles: 2, news: 3}

    def self.menu_items
      where('weight > 0').reorder(:weight)
    end

    def self.news
      where(type_id: 3).reorder(created_at: :desc)
    end

    def self.articles
      where(type_id: 2).reorder(created_at: :desc)
    end
  end
end