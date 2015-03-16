require 'spec_helper'

describe DirectoryItem do
  context 'refresh' do
    let!(:user) { Fabricate(:user) }

    it "creates the record for the user" do
      DirectoryItem.refresh!
      expect(DirectoryItem.where(period_type: DirectoryItem.period_types[:all])
                          .where(user_id: user.id)
                          .exists?).to be_true
    end

  end
end
