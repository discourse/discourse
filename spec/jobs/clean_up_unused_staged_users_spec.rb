require 'rails_helper'

RSpec.describe Jobs::CleanUpUnusedStagedUsers do
  let(:user) { Fabricate(:user) }
  let(:staged_user) { Fabricate(:user, staged: true) }

  context 'when staged user is unused' do
    it 'should clean up the staged user' do
      user
      staged_user.update!(created_at: 2.years.ago)

      expect { described_class.new.execute({}) }.to change { User.count }.by(-1)
      expect(User.find_by(id: staged_user.id)).to eq(nil)
    end

    describe 'when staged user is not old enough' do
      it 'should not clean up the staged user' do
        user
        staged_user.update!(created_at: 5.months.ago)

        expect { described_class.new.execute({}) }.to_not change { User.count }
        expect(User.find_by(id: staged_user.id)).to eq(staged_user)
      end
    end
  end

  context 'when staged user is not unused' do
    it 'should not clean up the staged user' do
      user
      Fabricate(:post, user: staged_user)
      user.update!(created_at: 2.years.ago)

      expect { described_class.new.execute({}) }.to_not change { User.count }
      expect(User.find_by(id: staged_user.id)).to eq(staged_user)
    end
  end
end
