require 'rails_helper'

module SitescanCommon
  RSpec.describe SearchResult, type: :model do
    it 'is invalid with a not unique link' do
      create :search_result
      search_result = build :search_result
      search_result.valid?
      expect(search_result.errors.added? :link, :taken).to be_truthy
    end
  end
end
