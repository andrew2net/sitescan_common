FactoryGirl.define do
  factory :sitescan_common_category, :class => 'SitescanCommon::Category' do
    name 'Phones'
    image_file_name 'noimage'
    image_content_type 'image/png'
    # parent_id 1
    # lfr 1
    # rgt 1
    # depth 1
    # children_count 1
    factory :category_with_key_words do
      after :create do |category, evaluator|
        create :key_word, category: category
      end
    end
  end

end
