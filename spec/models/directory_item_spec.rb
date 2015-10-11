require 'rails_helper'

describe DirectoryItem do
  context 'refresh' do
    let!(:post) { Fabricate(:post) }

    it "creates the record for the user" do
      DirectoryItem.refresh!
      expect(DirectoryItem.where(period_type: DirectoryItem.period_types[:all])
                          .where(user_id: post.user.id)
                          .exists?).to be_truthy
    end

  end
end
