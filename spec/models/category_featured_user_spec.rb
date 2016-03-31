require 'rails_helper'

describe CategoryFeaturedUser do

  it { is_expected.to belong_to :category }
  it { is_expected.to belong_to :user }

  context 'featuring users' do

    before do
      @category = Fabricate(:category)
      CategoryFeaturedUser.feature_users_in(@category)
    end

    it 'has a featured user' do
      expect(CategoryFeaturedUser.count).to be(1)
    end

    it 'returns the user via the category association' do
      expect(@category.featured_users).to be_present
    end

  end

end
