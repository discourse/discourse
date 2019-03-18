require 'rails_helper'

RSpec.describe Jobs::CleanUpInactiveUsers do
  context 'when user is inactive' do
    let(:user) { Fabricate(:user) }
    let(:active_user) { Fabricate(:active_user) }

    it 'should clean up the user' do
      user.update!(last_seen_at: 3.years.ago, trust_level: 0)
      active_user

      expect { described_class.new.execute({}) }.to change { User.count }.by(-1)
      expect(User.find_by(id: user.id)).to eq(nil)
    end
  end

  context 'when user is not inactive' do

    let!(:active_user_1) { Fabricate(:post, user: Fabricate(:user, trust_level: 0)).user }
    let!(:active_user_2) { Fabricate(:user, trust_level: 0, last_seen_at: 2.days.ago) }
    let!(:active_user_3) { Fabricate(:user, trust_level: 1) }

    it 'should not clean up active users' do
      expect { described_class.new.execute({}) }.to_not change { User.count }
      expect(User.find_by(id: active_user_1.id)).to_not eq(nil)
      expect(User.find_by(id: active_user_2.id)).to_not eq(nil)
      expect(User.find_by(id: active_user_3.id)).to_not eq(nil)
    end
  end
end
