require 'rails_helper'

describe GroupMessage do

  let(:moderators_group) { Group[:moderators].name }

  let!(:admin)     { Fabricate.build(:admin, id: 999) }
  let!(:user)      { Fabricate.build(:user, id: 111) }

  before do
    Discourse.stubs(:system_user).returns(admin)
  end

  subject(:send_group_message) { GroupMessage.create(moderators_group, :user_automatically_blocked, {user: user}) }

  describe 'not sent recently' do
    before { GroupMessage.any_instance.stubs(:sent_recently?).returns(false) }

    it 'should send a private message to the given group' do
      PostCreator.expects(:create).with do |from_user, opts|
          from_user.id == admin.id and
            opts[:target_group_names] and opts[:target_group_names].include?(Group[:moderators].name) and
            opts[:archetype] == Archetype.private_message and
            opts[:title].present? and
            opts[:raw].present?
        end.returns(stub_everything)
      send_group_message
    end

    it 'returns whatever PostCreator returns' do
      the_output = stub_everything
      PostCreator.stubs(:create).returns(the_output)
      expect(send_group_message).to eq(the_output)
    end

    it "remembers that it was sent so it doesn't spam the group with the same message" do
      PostCreator.stubs(:create).returns(stub_everything)
      GroupMessage.any_instance.expects(:remember_message_sent)
      send_group_message
    end
  end

  describe 'sent recently' do
    before  { GroupMessage.any_instance.stubs(:sent_recently?).returns(true) }
    subject { GroupMessage.create(moderators_group, :user_automatically_blocked, {user: user}) }

    it { is_expected.to eq(false) }

    it 'should not send the same notification again' do
      PostCreator.expects(:create).never
      subject
    end
  end

  describe 'message_params' do
    let(:user) { Fabricate.build(:user, id: 123123) }
    shared_examples 'common message params for group messages' do
      it 'returns the correct params' do
        expect(subject[:username]).to eq(user.username)
        expect(subject[:user_url]).to be_present
      end
    end

    context 'user_automatically_blocked' do
      subject { GroupMessage.new(moderators_group, :user_automatically_blocked, {user: user}).message_params }
      include_examples 'common message params for group messages'
    end

    context 'spam_post_blocked' do
      subject { GroupMessage.new(moderators_group, :spam_post_blocked, {user: user}).message_params }
      include_examples 'common message params for group messages'
    end
  end

  describe 'methods that use redis' do
    let(:user)              { Fabricate.build(:user, id: 123123) }
    subject(:group_message) { GroupMessage.new(moderators_group, :user_automatically_blocked, {user: user}) }
    before do
      PostCreator.stubs(:create).returns(stub_everything)
      group_message.stubs(:sent_recently_key).returns('the_key')
    end

    describe 'sent_recently?' do
      it 'returns true if redis says so' do
        $redis.stubs(:get).with(group_message.sent_recently_key).returns('1')
        expect(group_message.sent_recently?).to be_truthy
      end

      it 'returns false if redis returns nil' do
        $redis.stubs(:get).with(group_message.sent_recently_key).returns(nil)
        expect(group_message.sent_recently?).to be_falsey
      end

      it 'always returns false if limit_once_per is false' do
        gm = GroupMessage.new(moderators_group, :user_automatically_blocked, {user: user, limit_once_per: false})
        gm.stubs(:sent_recently_key).returns('the_key')
        $redis.stubs(:get).with(gm.sent_recently_key).returns('1')
        expect(gm.sent_recently?).to be_falsey
      end
    end

    describe 'remember_message_sent' do
      it 'stores a key in redis that expires after 24 hours' do
        $redis.expects(:setex).with(group_message.sent_recently_key, 24 * 60 * 60, anything).returns('OK')
        group_message.remember_message_sent
      end

      it 'can use a given expiry time' do
        $redis.expects(:setex).with(anything, 30 * 60, anything).returns('OK')
        GroupMessage.new(moderators_group, :user_automatically_blocked, {user: user, limit_once_per: 30.minutes}).remember_message_sent
      end

      it 'can be disabled' do
        $redis.expects(:setex).never
        GroupMessage.new(moderators_group, :user_automatically_blocked, {user: user, limit_once_per: false}).remember_message_sent
      end
    end
  end
end
