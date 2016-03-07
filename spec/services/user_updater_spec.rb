require 'rails_helper'

describe UserUpdater do

  let(:acting_user) { Fabricate.build(:user) }

  describe '#update_muted_users' do
    it 'has no cross talk' do
      u1 = Fabricate(:user)
      u2 = Fabricate(:user)
      u3 = Fabricate(:user)


      updater = UserUpdater.new(u1, u1)
      updater.update_muted_users("#{u2.username},#{u3.username}")

      updater = UserUpdater.new(u2, u2)
      updater.update_muted_users("#{u3.username},#{u1.username}")


      updater = UserUpdater.new(u3, u3)
      updater.update_muted_users("")


      expect(MutedUser.where(user_id: u2.id).count).to eq 2
      expect(MutedUser.where(user_id: u1.id).count).to eq 2
      expect(MutedUser.where(user_id: u3.id).count).to eq 0

    end
  end

  describe '#update' do
    it 'saves user' do
      user = Fabricate(:user, name: 'Billy Bob')
      updater = UserUpdater.new(acting_user, user)

      updater.update(name: 'Jim Tom')

      expect(user.reload.name).to eq 'Jim Tom'
    end

    it 'updates various fields' do
      user = Fabricate(:user)
      updater = UserUpdater.new(acting_user, user)

      updater.update(bio_raw: 'my new bio',
                     email_always: 'true',
                     mailing_list_mode: true,
                     digest_after_minutes: "45",
                     new_topic_duration_minutes: 100,
                     auto_track_topics_after_msecs: 101,
                     email_in_reply_to: false
                    )
      user.reload

      expect(user.user_profile.bio_raw).to eq 'my new bio'
      expect(user.user_option.email_always).to eq true
      expect(user.user_option.mailing_list_mode).to eq true
      expect(user.user_option.digest_after_minutes).to eq 45
      expect(user.user_option.new_topic_duration_minutes).to eq 100
      expect(user.user_option.auto_track_topics_after_msecs).to eq 101
      expect(user.user_option.email_in_reply_to).to eq false
    end

    context 'when update succeeds' do
      it 'returns true' do
        user = Fabricate(:user)
        updater = UserUpdater.new(acting_user, user)

        expect(updater.update).to be_truthy
      end
    end

    context 'when update fails' do
      it 'returns false' do
        user = Fabricate(:user)
        user.stubs(save: false)
        updater = UserUpdater.new(acting_user, user)

        expect(updater.update).to be_falsey
      end
    end

    context 'with permission to update title' do
      it 'allows user to change title' do
        user = Fabricate(:user, title: 'Emperor')
        guardian = stub
        guardian.stubs(:can_grant_title?).with(user).returns(true)
        Guardian.stubs(:new).with(acting_user).returns(guardian)
        updater = UserUpdater.new(acting_user, user)

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

    context 'when custom_fields is empty string' do
      it "update is successful" do
        user = Fabricate(:user)
        user.custom_fields = {'import_username' => 'my_old_username'}
        user.save
        updater = described_class.new(acting_user, user)

        updater.update(website: 'example.com', custom_fields: '')
        expect(user.reload.custom_fields).to eq({'import_username' => 'my_old_username'})
      end
    end
  end
end
