require 'spec_helper'

describe CategoryFeaturedUser do

  it { should belong_to :category }
  it { should belong_to :user }


  context 'featuring users' do

    before do
      @category = Fabricate(:category)
      CategoryFeaturedUser.feature_users_in(@category)
    end

    it 'has a featured user' do
      CategoryFeaturedUser.count.should_not == 0
    end

    it 'returns the user via the category association' do
      @category.featured_users.should be_present
    end

  end

end
