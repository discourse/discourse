require 'spec_helper'

describe UserUpdater do

  let(:acting_user) { Fabricate.build(:user) }

  describe '#update' do
    it 'saves user' do
      user = Fabricate(:user, name: 'Billy Bob')
      updater = described_class.new(acting_user, user)

      updater.update(name: 'Jim Tom')

      expect(user.reload.name).to eq 'Jim Tom'
    end

    it 'updates bio' do
      user = Fabricate(:user)
      updater = described_class.new(acting_user, user)

      updater.update(bio_raw: 'my new bio')

      expect(user.reload.user_profile.bio_raw).to eq 'my new bio'
    end

    context 'when update succeeds' do
      it 'returns true' do
        user = Fabricate(:user)
        updater = described_class.new(acting_user, user)

        expect(updater.update).to be_true
      end
    end

    context 'when update fails' do
      it 'returns false' do
        user = Fabricate(:user)
        user.stubs(save: false)
        updater = described_class.new(acting_user, user)

        expect(updater.update).to be_false
      end
    end

    context 'with permission to update title' do
      it 'allows user to change title' do
        user = Fabricate(:user, title: 'Emperor')
        guardian = stub
        guardian.stubs(:can_grant_title?).with(user).returns(true)
        Guardian.stubs(:new).with(acting_user).returns(guardian)
        updater = described_class.new(acting_user, user)

        updater.update(title: 'Minion')

        expect(user.reload.title).to eq 'Minion'
      end
    end

    context 'without permission to update title' do
      it 'does not allow user to change title' do
        user = Fabricate(:user, title: 'Emperor')
        guardian = stub
        guardian.stubs(:can_grant_title?).with(user).returns(false)
        Guardian.stubs(:new).with(acting_user).returns(guardian)
        updater = described_class.new(acting_user, user)

        updater.update(title: 'Minion')

        expect(user.reload.title).not_to eq 'Minion'
      end
    end

    context 'when website includes http' do
      it 'does not add http before updating' do
        user = Fabricate(:user)
        updater = described_class.new(acting_user, user)

        updater.update(website: 'http://example.com')

        expect(user.reload.user_profile.website).to eq 'http://example.com'
      end
    end

    context 'when website does not include http' do
      it 'adds http before updating' do
        user = Fabricate(:user)
        updater = described_class.new(acting_user, user)

        updater.update(website: 'example.com')

        expect(user.reload.user_profile.website).to eq 'http://example.com'
      end
    end
  end
end
