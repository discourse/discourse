require 'rails_helper'

describe SpamRule::AutoSilence do

  before do
    SiteSetting.flags_required_to_hide_post = 0 # never
    SiteSetting.num_spam_flags_to_silence_new_user = 2
    SiteSetting.num_users_to_silence_new_user = 2
  end

  describe 'perform' do
    let(:post)  { Fabricate.build(:post, user: Fabricate.build(:user, trust_level: TrustLevel[0])) }
    subject     { described_class.new(post.user) }

    it 'takes no action if user should not be silenced' do
      subject.stubs(:silence?).returns(false)
      subject.expects(:silence_user).never
      subject.perform
    end

    it 'delivers punishment when user should be silenced' do
      subject.stubs(:silence?).returns(true)
      subject.expects(:silence_user)
      subject.perform
    end
  end

  describe 'num_spam_flags_against_user' do
    before { described_class.any_instance.stubs(:silence_user) }
    let(:post)     { Fabricate(:post) }
    let(:enforcer) { described_class.new(post.user) }
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
    before { described_class.any_instance.stubs(:silence_user) }
    let(:post)     { Fabricate(:post) }
    let(:enforcer) { described_class.new(post.user) }
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

  describe 'num_tl3_flags_against_user' do
    let(:post)     { Fabricate(:post) }
    let(:enforcer) { described_class.new(post.user) }

    it "counts flags of all types from tl3 users only" do
      Fabricate(:flag, post: post, user: Fabricate(:user, trust_level: 1), post_action_type_id: PostActionType.types[:inappropriate])
      expect(enforcer.num_tl3_flags_against_user).to eq(0)
      Fabricate(:flag, post: post, user: Fabricate(:user, trust_level: 3), post_action_type_id: PostActionType.types[:inappropriate])
      expect(enforcer.num_tl3_flags_against_user).to eq(1)
      Fabricate(:flag, post: post, user: Fabricate(:user, trust_level: 1), post_action_type_id: PostActionType.types[:spam])
      Fabricate(:flag, post: post, user: Fabricate(:user, trust_level: 3), post_action_type_id: PostActionType.types[:spam])
      expect(enforcer.num_tl3_flags_against_user).to eq(2)
    end
  end

  describe 'num_tl3_users_who_flagged' do
    let(:post)     { Fabricate(:post) }
    let(:enforcer) { described_class.new(post.user) }

    it "counts only tl3 users who flagged with any type" do
      Fabricate(:flag, post: post, user: Fabricate(:user, trust_level: 1), post_action_type_id: PostActionType.types[:inappropriate])
      expect(enforcer.num_tl3_users_who_flagged).to eq(0)

      tl3_user1 = Fabricate(:user, trust_level: 3)
      Fabricate(:flag, post: post, user: tl3_user1, post_action_type_id: PostActionType.types[:inappropriate])
      expect(enforcer.num_tl3_users_who_flagged).to eq(1)

      Fabricate(:flag, post: post, user: Fabricate(:user, trust_level: 1), post_action_type_id: PostActionType.types[:spam])
      expect(enforcer.num_tl3_users_who_flagged).to eq(1)

      Fabricate(:flag, post: post, user: Fabricate(:user, trust_level: 3), post_action_type_id: PostActionType.types[:spam])
      expect(enforcer.num_tl3_users_who_flagged).to eq(2)

      Fabricate(:flag, post: Fabricate(:post, user: post.user), user: tl3_user1, post_action_type_id: PostActionType.types[:inappropriate])
      expect(enforcer.num_tl3_users_who_flagged).to eq(2)
    end
  end

  describe 'silence_user' do
    let!(:admin)  { Fabricate(:admin) } # needed for SystemMessage
    let(:user)    { Fabricate(:user) }
    let!(:post)   { Fabricate(:post, user: user) }
    subject       { described_class.new(user) }

    before do
      described_class.stubs(:silence?).with { |u| u.id != user.id }.returns(false)
      described_class.stubs(:silence?).with { |u| u.id == user.id }.returns(true)
      subject.stubs(:silence?).returns(true)
    end

    context 'user is not silenced' do
      before do
        UserSilencer.expects(:silence).with(user, Discourse.system_user, message: :too_many_spam_flags).returns(true)
      end

      it 'prevents the user from making new posts' do
        subject.silence_user
        expect(Guardian.new(user).can_create_post?(nil)).to be_falsey
      end

      it 'sends private message to moderators' do
        SiteSetting.notify_mods_when_user_silenced = true
        moderator = Fabricate(:moderator)
        GroupMessage.expects(:create).with do |group, msg_type, params|
          group == (Group[:moderators].name) && msg_type == (:user_automatically_silenced) && params[:user].id == (user.id)
        end
        subject.silence_user
      end

      it "doesn't send a pm to moderators if notify_mods_when_user_silenced is false" do
        SiteSetting.notify_mods_when_user_silenced = false
        GroupMessage.expects(:create).never
        subject.silence_user
      end
    end

    context 'user is already silenced' do
      before do
        UserSilencer.expects(:silence).with(user, Discourse.system_user, message: :too_many_spam_flags).returns(false)
      end

      it "doesn't send a pm to moderators if the user is already silenced" do
        GroupMessage.expects(:create).never
        subject.silence_user
      end
    end
  end

  describe 'silence?' do

    context 'never been silenced' do
      shared_examples "can't be silenced" do
        it "returns false" do
          enforcer = described_class.new(user)
          enforcer.expects(:num_spam_flags_against_user).never
          enforcer.expects(:num_users_who_flagged_spam_against_user).never
          enforcer.expects(:num_flags_against_user).never
          enforcer.expects(:num_users_who_flagged).never
          expect(enforcer.silence?).to eq(false)
        end
      end

      (1..4).each do |trust_level|
        context "user has trust level #{trust_level}" do
          let(:user) { Fabricate(:user, trust_level: trust_level) }
          include_examples "can't be silenced"
        end
      end

      context "user is an admin" do
        let(:user) { Fabricate(:admin) }
        include_examples "can't be silenced"
      end

      context "user is a moderator" do
        let(:user) { Fabricate(:moderator) }
        include_examples "can't be silenced"
      end
    end

    context 'new user' do
      let(:user)  { Fabricate(:user, trust_level: TrustLevel[0]) }
      subject     { described_class.new(user) }

      it 'returns false if there are no spam flags' do
        subject.stubs(:num_spam_flags_against_user).returns(0)
        subject.stubs(:num_users_who_flagged_spam_against_user).returns(0)
        expect(subject.silence?).to be_falsey
      end

      it 'returns false if there are not received enough flags' do
        subject.stubs(:num_spam_flags_against_user).returns(1)
        subject.stubs(:num_users_who_flagged_spam_against_user).returns(2)
        expect(subject.silence?).to be_falsey
      end

      it 'returns false if there have not been enough users' do
        subject.stubs(:num_spam_flags_against_user).returns(2)
        subject.stubs(:num_users_who_flagged_spam_against_user).returns(1)
        expect(subject.silence?).to be_falsey
      end

      it 'returns false if num_spam_flags_to_silence_new_user is 0' do
        SiteSetting.num_spam_flags_to_silence_new_user = 0
        subject.stubs(:num_spam_flags_against_user).returns(100)
        subject.stubs(:num_users_who_flagged_spam_against_user).returns(100)
        expect(subject.silence?).to be_falsey
      end

      it 'returns false if num_users_to_silence_new_user is 0' do
        SiteSetting.num_users_to_silence_new_user = 0
        subject.stubs(:num_spam_flags_against_user).returns(100)
        subject.stubs(:num_users_who_flagged_spam_against_user).returns(100)
        expect(subject.silence?).to be_falsey
      end

      it 'returns true when there are enough flags from enough users' do
        subject.stubs(:num_spam_flags_against_user).returns(2)
        subject.stubs(:num_users_who_flagged_spam_against_user).returns(2)
        expect(subject.silence?).to be_truthy
      end

      context "all types of flags" do
        before do
          SiteSetting.num_tl3_flags_to_silence_new_user = 3
          SiteSetting.num_tl3_users_to_silence_new_user = 2
        end

        it 'returns false if there are not enough flags' do
          subject.stubs(:num_tl3_flags_against_user).returns(1)
          subject.stubs(:num_tl3_users_who_flagged).returns(1)
          expect(subject.silence?).to be_falsey
        end

        it 'returns false if enough flags but not enough users' do
          subject.stubs(:num_tl3_flags_against_user).returns(3)
          subject.stubs(:num_tl3_users_who_flagged).returns(1)
          expect(subject.silence?).to be_falsey
        end

        it 'returns true if enough flags and users' do
          subject.stubs(:num_tl3_flags_against_user).returns(3)
          subject.stubs(:num_tl3_users_who_flagged).returns(2)
          expect(subject.silence?).to eq(true)
        end
      end
    end

    context "silenced, but has higher trust level now" do
      let(:user)  { Fabricate(:user, silenced_till: 1.year.from_now, trust_level: TrustLevel[1]) }
      subject     { described_class.new(user) }

      it 'returns false' do
        expect(subject.silence?).to be_truthy
      end
    end
  end
end
