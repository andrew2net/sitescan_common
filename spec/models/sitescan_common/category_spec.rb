require 'rails_helper'

RSpec.describe Category, type: :model do
  it "should create category" do
    create :sitescan_common_category
    c = SitescanCommon::Category.first
    expect(c.name).to eq 'Phones'
  end
end
