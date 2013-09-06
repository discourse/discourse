require 'spec_helper'

describe SpamRulesEnforcer do

  before do
    SystemMessage.stubs(:create)
  end

  before do
    SiteSetting.stubs(:flags_required_to_hide_post).returns(0) # never
    SiteSetting.stubs(:num_flags_to_block_new_user).returns(2)
    SiteSetting.stubs(:num_users_to_block_new_user).returns(2)
  end

  describe 'enforce!' do
    let(:post)  { Fabricate.build(:post, user: Fabricate.build(:user, trust_level: TrustLevel.levels[:newuser])) }
    subject     { SpamRulesEnforcer.new(post.user) }

    it "does nothing if the user's trust level is higher than 'new user'" do
      basic_user = Fabricate.build(:user, trust_level: TrustLevel.levels[:basic])
      enforcer = SpamRulesEnforcer.new(basic_user)
      enforcer.expects(:num_spam_flags_against_user).never
      enforcer.expects(:num_users_who_flagged_spam_against_user).never
      enforcer.expects(:punish_user).never
      enforcer.enforce!
    end

    it 'takes no action if not enough flags by enough users have been submitted' do
      subject.stubs(:block?).returns(false)
      subject.expects(:punish_user).never
      subject.enforce!
    end

    it 'delivers punishment when there are enough flags from enough users' do
      subject.stubs(:block?).returns(true)
      subject.expects(:punish_user)
      subject.enforce!
    end
  end

  describe 'num_spam_flags_against_user' do
    before { SpamRulesEnforcer.any_instance.stubs(:punish_user) }
    let(:post)     { Fabricate(:post) }
    let(:enforcer) { SpamRulesEnforcer.new(post.user) }
    subject        { enforcer.num_spam_flags_against_user }

    it 'returns 0 when there are no flags' do
      expect(subject).to eq(0)
    end

    it 'returns 0 when there is one flag that has a reason other than spam' do
      Fabricate(:flag, post: post, post_action_type_id: PostActionType.types[:off_topic])
      expect(subject).to eq(0)
    end

    it 'returns 2 when there are two flags with spam as the reason' do
      2.times { Fabricate(:flag, post: post, post_action_type_id: PostActionType.types[:spam]) }
      expect(subject).to eq(2)
    end

    it 'returns 2 when there are two spam flags, each on a different post' do
      Fabricate(:flag, post: post, post_action_type_id: PostActionType.types[:spam])
      Fabricate(:flag, post: Fabricate(:post, user: post.user), post_action_type_id: PostActionType.types[:spam])
      expect(subject).to eq(2)
    end
  end

  describe 'num_users_who_flagged_spam_against_user' do
    before { SpamRulesEnforcer.any_instance.stubs(:punish_user) }
    let(:post)     { Fabricate(:post) }
    let(:enforcer) { SpamRulesEnforcer.new(post.user) }
    subject        { enforcer.num_users_who_flagged_spam_against_user }

    it 'returns 0 when there are no flags' do
      expect(subject).to eq(0)
    end

    it 'returns 0 when there is one flag that has a reason other than spam' do
      Fabricate(:flag, post: post, post_action_type_id: PostActionType.types[:off_topic])
      expect(subject).to eq(0)
    end

    it 'returns 1 when there is one spam flag' do
      Fabricate(:flag, post: post, post_action_type_id: PostActionType.types[:spam])
      expect(subject).to eq(1)
    end

    it 'returns 2 when there are two spam flags from 2 users' do
      Fabricate(:flag, post: post, post_action_type_id: PostActionType.types[:spam])
      Fabricate(:flag, post: post, post_action_type_id: PostActionType.types[:spam])
      expect(subject).to eq(2)
    end

    it 'returns 1 when there are two spam flags on two different posts from 1 user' do
      flagger = Fabricate(:user)
      Fabricate(:flag, post: post, user: flagger, post_action_type_id: PostActionType.types[:spam])
      Fabricate(:flag, post: Fabricate(:post, user: post.user), user: flagger, post_action_type_id: PostActionType.types[:spam])
      expect(subject).to eq(1)
    end
  end

  describe 'punish_user' do
    let!(:admin)  { Fabricate(:admin) } # needed for SystemMessage
    let(:user)    { Fabricate(:user) }
    let!(:post)   { Fabricate(:post, user: user) }
    subject       { SpamRulesEnforcer.new(user) }

    before do
      SpamRulesEnforcer.stubs(:block?).with {|u| u.id != user.id }.returns(false)
      SpamRulesEnforcer.stubs(:block?).with {|u| u.id == user.id }.returns(true)
      subject.stubs(:block?).returns(true)
    end

    context 'user is not blocked' do
      before do
        UserBlocker.expects(:block).with(user, nil, has_entries(message: :too_many_spam_flags)).returns(true)
      end

      it 'prevents the user from making new posts' do
        subject.punish_user
        expect(Guardian.new(user).can_create_post?(nil)).to be_false
      end

      it 'sends private message to moderators' do
        SiteSetting.stubs(:notify_mods_when_user_blocked).returns(true)
        moderator = Fabricate(:moderator)
        GroupMessage.expects(:create).with do |group, msg_type, params|
          group == Group[:moderators].name and msg_type == :user_automatically_blocked and params[:user].id == user.id
        end
        subject.punish_user
      end

      it "doesn't send a pm to moderators if notify_mods_when_user_blocked is false" do
        SiteSetting.stubs(:notify_mods_when_user_blocked).returns(false)
        GroupMessage.expects(:create).never
        subject.punish_user
      end
    end

    context 'user is already blocked' do
      before do
        UserBlocker.expects(:block).with(user, nil, has_entries(message: :too_many_spam_flags)).returns(false)
      end

      it "doesn't send a pm to moderators if the user is already blocked" do
        GroupMessage.expects(:create).never
        subject.punish_user
      end
    end
  end

  describe 'block?' do

    context 'never been blocked' do
      shared_examples "can't be blocked" do
        it "returns false" do
          enforcer = SpamRulesEnforcer.new(user)
          enforcer.expects(:num_spam_flags_against_user).never
          enforcer.expects(:num_users_who_flagged_spam_against_user).never
          expect(enforcer.block?).to be_false
        end
      end

      [:basic, :regular, :leader, :elder].each do |trust_level|
        context "user has trust level #{trust_level}" do
          let(:user) { Fabricate(:user, trust_level: TrustLevel.levels[trust_level]) }
          include_examples "can't be blocked"
        end
      end

      context "user is an admin" do
        let(:user) { Fabricate(:admin) }
        include_examples "can't be blocked"
      end

      context "user is a moderator" do
        let(:user) { Fabricate(:moderator) }
        include_examples "can't be blocked"
      end
    end

    context 'new user' do
      let(:user)  { Fabricate(:user, trust_level: TrustLevel.levels[:newuser]) }
      subject     { SpamRulesEnforcer.new(user) }

      it 'returns false if there are no spam flags' do
        subject.stubs(:num_spam_flags_against_user).returns(0)
        subject.stubs(:num_users_who_flagged_spam_against_user).returns(0)
        expect(subject.block?).to be_false
      end

      it 'returns false if there are not received enough flags' do
        subject.stubs(:num_spam_flags_against_user).returns(1)
        subject.stubs(:num_users_who_flagged_spam_against_user).returns(2)
        expect(subject.block?).to be_false
      end

      it 'returns false if there have not been enough users' do
        subject.stubs(:num_spam_flags_against_user).returns(2)
        subject.stubs(:num_users_who_flagged_spam_against_user).returns(1)
        expect(subject.block?).to be_false
      end

      it 'returns false if num_flags_to_block_new_user is 0' do
        SiteSetting.stubs(:num_flags_to_block_new_user).returns(0)
        subject.stubs(:num_spam_flags_against_user).returns(100)
        subject.stubs(:num_users_who_flagged_spam_against_user).returns(100)
        expect(subject.block?).to be_false
      end

      it 'returns false if num_users_to_block_new_user is 0' do
        SiteSetting.stubs(:num_users_to_block_new_user).returns(0)
        subject.stubs(:num_spam_flags_against_user).returns(100)
        subject.stubs(:num_users_who_flagged_spam_against_user).returns(100)
        expect(subject.block?).to be_false
      end

      it 'returns true when there are enough flags from enough users' do
        subject.stubs(:num_spam_flags_against_user).returns(2)
        subject.stubs(:num_users_who_flagged_spam_against_user).returns(2)
        expect(subject.block?).to be_true
      end
    end

    context "blocked, but has higher trust level now" do
      let(:user)  { Fabricate(:user, blocked: true, trust_level: TrustLevel.levels[:basic]) }
      subject     { SpamRulesEnforcer.new(user) }

      it 'returns false' do
        expect(subject.block?).to be_true
      end
    end
  end

end
