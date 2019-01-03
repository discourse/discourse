require 'rails_helper'

describe SpamRule::AutoSilence do

  before do
    SiteSetting.score_required_to_hide_post = 0 # never
    SiteSetting.spam_score_to_silence_new_user = 4.0
    SiteSetting.num_users_to_silence_new_user = 2
  end

  describe 'perform' do
    let(:user) { Fabricate.build(:newuser) }
    let(:post) { Fabricate(:post, user: user) }
    subject { described_class.new(post.user) }

    it 'takes no action if user should not be silenced' do
      subject.perform
      expect(post.user.reload).not_to be_silenced
    end

    it 'delivers punishment when user should be silenced' do
      SiteSetting.spam_score_to_silence_new_user = 2.0
      SiteSetting.num_users_to_silence_new_user = 1
      PostActionCreator.spam(Discourse.system_user, post)
      subject.perform
      expect(post.user.reload).to be_silenced
    end
  end

  describe 'total_spam_score' do
    let(:post) { Fabricate(:post) }
    let(:enforcer) { described_class.new(post.user) }
    let(:flagger) { Fabricate(:user) }
    subject { enforcer.user_spam_stats.total_spam_score }

    it 'returns 0 when there are no flags' do
      expect(subject).to eq(0)
    end

    it 'returns 0 when there is one flag that has a reason other than spam' do
      PostActionCreator.off_topic(flagger, post)
      expect(subject).to eq(0)
    end

    it 'returns the score when there are two flags with spam as the reason' do
      PostActionCreator.spam(Fabricate(:user), post)
      PostActionCreator.spam(Fabricate(:user), post)
      expect(subject).to eq(4.0)
    end

    it 'returns the score when there are two spam flags, each on a different post' do
      PostActionCreator.spam(Fabricate(:user), post)
      PostActionCreator.spam(Fabricate(:user), Fabricate(:post, user: post.user))
      expect(subject).to eq(4.0)
    end
  end

  describe 'spam_user_count' do
    let(:post)     { Fabricate(:post) }
    let(:enforcer) { described_class.new(post.user) }
    subject        { enforcer.user_spam_stats.spam_user_count }

    it 'returns 0 when there are no flags' do
      expect(subject).to eq(0)
    end

    it 'returns 0 when there is one flag that has a reason other than spam' do
      Fabricate(:flag, post: post, post_action_type_id: PostActionType.types[:off_topic])
      expect(subject).to eq(0)
    end

    it 'returns 1 when there is one spam flag' do
      PostActionCreator.spam(Fabricate(:user), post)
      expect(subject).to eq(1)
    end

    it 'returns 2 when there are two spam flags from 2 users' do
      PostActionCreator.spam(Fabricate(:user), post)
      PostActionCreator.spam(Fabricate(:user), post)
      expect(subject).to eq(2)
    end

    it 'returns 1 when there are two spam flags on two different posts from 1 user' do
      flagger = Fabricate(:user)
      PostActionCreator.spam(flagger, post)
      PostActionCreator.spam(flagger, Fabricate(:post, user: post.user))
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

    context 'user is not silenced' do
      it 'prevents the user from making new posts' do
        subject.silence_user
        expect(user).to be_silenced
        expect(Guardian.new(user).can_create_post?(nil)).to be_falsey
      end

      context "with a moderator" do
        let!(:moderator) { Fabricate(:moderator) }

        it 'sends private message to moderators' do
          SiteSetting.notify_mods_when_user_silenced = true
          subject.silence_user
          expect(subject.group_message).to be_present
        end

        it "doesn't send a pm to moderators if notify_mods_when_user_silenced is false" do
          SiteSetting.notify_mods_when_user_silenced = false
          subject.silence_user
          expect(subject.group_message).to be_blank
        end
      end
    end

    context 'user is already silenced' do
      before do
        UserSilencer.silence(user)
      end

      it "doesn't send a pm to moderators if the user is already silenced" do
        subject.silence_user
        expect(subject.group_message).to be_blank
      end
    end
  end

  describe 'autosilenced?' do
    let(:user) { Fabricate(:newuser) }
    let(:flagger) { Fabricate(:user) }
    let(:flagger2) { Fabricate(:user) }
    let(:post) { Fabricate(:post, user: user) }
    let(:post2) { Fabricate(:post, user: user) }

    context "higher trust levels or staff" do
      it "should not autosilence any of them" do
        PostActionCreator.spam(flagger, post)
        PostActionCreator.spam(flagger2, post)

        enforcer = described_class.new(user)
        expect(enforcer.should_autosilence?).to eq(true)

        user.trust_level = 1
        expect(enforcer.should_autosilence?).to eq(false)

        user.trust_level = 2
        expect(enforcer.should_autosilence?).to eq(false)

        user.trust_level = 3
        expect(enforcer.should_autosilence?).to eq(false)

        user.trust_level = 4
        expect(enforcer.should_autosilence?).to eq(false)

        user.trust_level = 0
        user.moderator = true
        expect(enforcer.should_autosilence?).to eq(false)

        user.moderator = false
        user.admin = true
        expect(enforcer.should_autosilence?).to eq(false)
      end
    end

    context 'new user' do
      subject { described_class.new(user) }
      let(:stats) { subject.user_spam_stats }

      it 'returns false if there are no spam flags' do
        expect(stats.total_spam_score).to eq(0)
        expect(stats.spam_user_count).to eq(0)
        expect(subject.should_autosilence?).to eq(false)
      end

      it 'returns false if there are not received enough flags' do
        PostActionCreator.spam(flagger, post)
        expect(stats.total_spam_score).to eq(2.0)
        expect(stats.spam_user_count).to eq(1)
        expect(subject.should_autosilence?).to eq(false)
      end

      it 'returns false if there have not been enough users' do
        PostActionCreator.spam(flagger, post)
        PostActionCreator.spam(flagger, post2)
        expect(stats.total_spam_score).to eq(4.0)
        expect(stats.spam_user_count).to eq(1)
        expect(subject.should_autosilence?).to eq(false)
      end

      it 'returns false if spam_score_to_silence_new_user is 0' do
        SiteSetting.spam_score_to_silence_new_user = 0
        PostActionCreator.spam(flagger, post)
        PostActionCreator.spam(flagger2, post)
        expect(subject.should_autosilence?).to eq(false)
      end

      it 'returns false if num_users_to_silence_new_user is 0' do
        SiteSetting.num_users_to_silence_new_user = 0
        PostActionCreator.spam(flagger, post)
        PostActionCreator.spam(flagger2, post)
        expect(subject.should_autosilence?).to eq(false)
      end

      it 'returns true when there are enough flags from enough users' do
        PostActionCreator.spam(flagger, post)
        PostActionCreator.spam(flagger2, post)
        expect(stats.total_spam_score).to eq(4.0)
        expect(stats.spam_user_count).to eq(2)
        expect(subject.should_autosilence?).to eq(true)
      end

      context "all types of flags" do
        let(:leader1) { Fabricate(:leader) }
        let(:leader2) { Fabricate(:leader) }

        before do
          SiteSetting.num_tl3_flags_to_silence_new_user = 3
          SiteSetting.num_tl3_users_to_silence_new_user = 2
        end

        it 'returns false if there are not enough flags' do
          PostActionCreator.inappropriate(leader1, post)
          expect(subject.num_tl3_flags_against_user).to eq(1)
          expect(subject.num_tl3_users_who_flagged).to eq(1)
          expect(subject.should_autosilence?).to be_falsey
        end

        it 'returns false if enough flags but not enough users' do
          PostActionCreator.inappropriate(leader1, post)
          PostActionCreator.inappropriate(leader1, post2)
          PostActionCreator.inappropriate(leader1, Fabricate(:post, user: user))
          expect(subject.num_tl3_flags_against_user).to eq(3)
          expect(subject.num_tl3_users_who_flagged).to eq(1)
          expect(subject.should_autosilence?).to eq(false)
        end

        it 'returns true if enough flags and users' do
          PostActionCreator.inappropriate(leader1, post)
          PostActionCreator.inappropriate(leader1, post2)
          PostActionCreator.inappropriate(leader2, post)
          expect(subject.num_tl3_flags_against_user).to eq(3)
          expect(subject.num_tl3_users_who_flagged).to eq(2)
          expect(subject.should_autosilence?).to eq(true)
        end
      end
    end

    context "silenced, but has higher trust level now" do
      let(:user)  { Fabricate(:user, silenced_till: 1.year.from_now, trust_level: TrustLevel[1]) }
      subject     { described_class.new(user) }

      it 'returns false' do
        expect(subject.should_autosilence?).to eq(false)
      end
    end
  end
end
