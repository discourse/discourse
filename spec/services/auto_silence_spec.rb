require 'rails_helper'

describe SpamRule::AutoSilence do
  before do
    SiteSetting.flags_required_to_hide_post = 0 # never
    SiteSetting.num_spam_flags_to_silence_new_user = 2
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
      SiteSetting.num_spam_flags_to_silence_new_user = 1
      SiteSetting.num_users_to_silence_new_user = 1
      PostAction.act(Discourse.system_user, post, PostActionType.types[:spam])
      subject.perform
      expect(post.user.reload).to be_silenced
    end
  end

  describe 'num_spam_flags_against_user' do
    let(:post) { Fabricate(:post) }
    let(:enforcer) { described_class.new(post.user) }
    subject { enforcer.num_spam_flags_against_user }

    it 'returns 0 when there are no flags' do
      expect(subject).to eq(0)
    end

    it 'returns 0 when there is one flag that has a reason other than spam' do
      Fabricate(
        :flag,
        post: post, post_action_type_id: PostActionType.types[:off_topic]
      )
      expect(subject).to eq(0)
    end

    it 'returns 2 when there are two flags with spam as the reason' do
      2.times do
        Fabricate(
          :flag,
          post: post, post_action_type_id: PostActionType.types[:spam]
        )
      end
      expect(subject).to eq(2)
    end

    it 'returns 2 when there are two spam flags, each on a different post' do
      Fabricate(
        :flag,
        post: post, post_action_type_id: PostActionType.types[:spam]
      )
      Fabricate(
        :flag,
        post: Fabricate(:post, user: post.user),
        post_action_type_id: PostActionType.types[:spam]
      )
      expect(subject).to eq(2)
    end
  end

  describe 'num_users_who_flagged_spam_against_user' do
    let(:post) { Fabricate(:post) }
    let(:enforcer) { described_class.new(post.user) }
    subject { enforcer.num_users_who_flagged_spam_against_user }

    it 'returns 0 when there are no flags' do
      expect(subject).to eq(0)
    end

    it 'returns 0 when there is one flag that has a reason other than spam' do
      Fabricate(
        :flag,
        post: post, post_action_type_id: PostActionType.types[:off_topic]
      )
      expect(subject).to eq(0)
    end

    it 'returns 1 when there is one spam flag' do
      Fabricate(
        :flag,
        post: post, post_action_type_id: PostActionType.types[:spam]
      )
      expect(subject).to eq(1)
    end

    it 'returns 2 when there are two spam flags from 2 users' do
      Fabricate(
        :flag,
        post: post, post_action_type_id: PostActionType.types[:spam]
      )
      Fabricate(
        :flag,
        post: post, post_action_type_id: PostActionType.types[:spam]
      )
      expect(subject).to eq(2)
    end

    it 'returns 1 when there are two spam flags on two different posts from 1 user' do
      flagger = Fabricate(:user)
      Fabricate(
        :flag,
        post: post,
        user: flagger,
        post_action_type_id: PostActionType.types[:spam]
      )
      Fabricate(
        :flag,
        post: Fabricate(:post, user: post.user),
        user: flagger,
        post_action_type_id: PostActionType.types[:spam]
      )
      expect(subject).to eq(1)
    end
  end

  describe 'num_tl3_flags_against_user' do
    let(:post) { Fabricate(:post) }
    let(:enforcer) { described_class.new(post.user) }

    it 'counts flags of all types from tl3 users only' do
      Fabricate(
        :flag,
        post: post,
        user: Fabricate(:user, trust_level: 1),
        post_action_type_id: PostActionType.types[:inappropriate]
      )
      expect(enforcer.num_tl3_flags_against_user).to eq(0)
      Fabricate(
        :flag,
        post: post,
        user: Fabricate(:user, trust_level: 3),
        post_action_type_id: PostActionType.types[:inappropriate]
      )
      expect(enforcer.num_tl3_flags_against_user).to eq(1)
      Fabricate(
        :flag,
        post: post,
        user: Fabricate(:user, trust_level: 1),
        post_action_type_id: PostActionType.types[:spam]
      )
      Fabricate(
        :flag,
        post: post,
        user: Fabricate(:user, trust_level: 3),
        post_action_type_id: PostActionType.types[:spam]
      )
      expect(enforcer.num_tl3_flags_against_user).to eq(2)
    end
  end

  describe 'num_tl3_users_who_flagged' do
    let(:post) { Fabricate(:post) }
    let(:enforcer) { described_class.new(post.user) }

    it 'counts only tl3 users who flagged with any type' do
      Fabricate(
        :flag,
        post: post,
        user: Fabricate(:user, trust_level: 1),
        post_action_type_id: PostActionType.types[:inappropriate]
      )
      expect(enforcer.num_tl3_users_who_flagged).to eq(0)

      tl3_user1 = Fabricate(:user, trust_level: 3)
      Fabricate(
        :flag,
        post: post,
        user: tl3_user1,
        post_action_type_id: PostActionType.types[:inappropriate]
      )
      expect(enforcer.num_tl3_users_who_flagged).to eq(1)

      Fabricate(
        :flag,
        post: post,
        user: Fabricate(:user, trust_level: 1),
        post_action_type_id: PostActionType.types[:spam]
      )
      expect(enforcer.num_tl3_users_who_flagged).to eq(1)

      Fabricate(
        :flag,
        post: post,
        user: Fabricate(:user, trust_level: 3),
        post_action_type_id: PostActionType.types[:spam]
      )
      expect(enforcer.num_tl3_users_who_flagged).to eq(2)

      Fabricate(
        :flag,
        post: Fabricate(:post, user: post.user),
        user: tl3_user1,
        post_action_type_id: PostActionType.types[:inappropriate]
      )
      expect(enforcer.num_tl3_users_who_flagged).to eq(2)
    end
  end

  describe 'silence_user' do
    let!(:admin) { Fabricate(:admin) } # needed for SystemMessage
    let(:user) { Fabricate(:user) }
    let!(:post) { Fabricate(:post, user: user) }
    subject { described_class.new(user) }

    context 'user is not silenced' do
      it 'prevents the user from making new posts' do
        subject.silence_user
        expect(user).to be_silenced
        expect(Guardian.new(user).can_create_post?(nil)).to be_falsey
      end

      context 'with a moderator' do
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
      before { UserSilencer.silence(user) }

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

    context 'higher trust levels or staff' do
      it 'should not autosilence any of them' do
        PostAction.act(flagger, post, PostActionType.types[:spam])
        PostAction.act(flagger2, post, PostActionType.types[:spam])

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

      it 'returns false if there are no spam flags' do
        expect(subject.num_spam_flags_against_user).to eq(0)
        expect(subject.num_users_who_flagged_spam_against_user).to eq(0)
        expect(subject.should_autosilence?).to eq(false)
      end

      it 'returns false if there are not received enough flags' do
        PostAction.act(flagger, post, PostActionType.types[:spam])
        expect(subject.num_spam_flags_against_user).to eq(1)
        expect(subject.num_users_who_flagged_spam_against_user).to eq(1)
        expect(subject.should_autosilence?).to eq(false)
      end

      it 'returns false if there have not been enough users' do
        PostAction.act(flagger, post, PostActionType.types[:spam])
        PostAction.act(flagger, post2, PostActionType.types[:spam])
        expect(subject.num_spam_flags_against_user).to eq(2)
        expect(subject.num_users_who_flagged_spam_against_user).to eq(1)
        expect(subject.should_autosilence?).to eq(false)
      end

      it 'returns false if num_spam_flags_to_silence_new_user is 0' do
        SiteSetting.num_spam_flags_to_silence_new_user = 0
        PostAction.act(flagger, post, PostActionType.types[:spam])
        PostAction.act(flagger2, post, PostActionType.types[:spam])
        expect(subject.should_autosilence?).to eq(false)
      end

      it 'returns false if num_users_to_silence_new_user is 0' do
        SiteSetting.num_users_to_silence_new_user = 0
        PostAction.act(flagger, post, PostActionType.types[:spam])
        PostAction.act(flagger2, post, PostActionType.types[:spam])
        expect(subject.should_autosilence?).to eq(false)
      end

      it 'returns true when there are enough flags from enough users' do
        PostAction.act(flagger, post, PostActionType.types[:spam])
        PostAction.act(flagger2, post, PostActionType.types[:spam])
        expect(subject.num_spam_flags_against_user).to eq(2)
        expect(subject.num_users_who_flagged_spam_against_user).to eq(2)
        expect(subject.should_autosilence?).to eq(true)
      end

      context 'all types of flags' do
        let(:leader1) { Fabricate(:leader) }
        let(:leader2) { Fabricate(:leader) }

        before do
          SiteSetting.num_tl3_flags_to_silence_new_user = 3
          SiteSetting.num_tl3_users_to_silence_new_user = 2
        end

        it 'returns false if there are not enough flags' do
          PostAction.act(leader1, post, PostActionType.types[:inappropriate])
          expect(subject.num_tl3_flags_against_user).to eq(1)
          expect(subject.num_tl3_users_who_flagged).to eq(1)
          expect(subject.should_autosilence?).to be_falsey
        end

        it 'returns false if enough flags but not enough users' do
          PostAction.act(leader1, post, PostActionType.types[:inappropriate])
          PostAction.act(leader1, post2, PostActionType.types[:inappropriate])
          PostAction.act(
            leader1,
            Fabricate(:post, user: user),
            PostActionType.types[:inappropriate]
          )
          expect(subject.num_tl3_flags_against_user).to eq(3)
          expect(subject.num_tl3_users_who_flagged).to eq(1)
          expect(subject.should_autosilence?).to eq(false)
        end

        it 'returns true if enough flags and users' do
          PostAction.act(leader1, post, PostActionType.types[:inappropriate])
          PostAction.act(leader1, post2, PostActionType.types[:inappropriate])
          PostAction.act(leader2, post, PostActionType.types[:inappropriate])
          expect(subject.num_tl3_flags_against_user).to eq(3)
          expect(subject.num_tl3_users_who_flagged).to eq(2)
          expect(subject.should_autosilence?).to eq(true)
        end
      end
    end

    context 'silenced, but has higher trust level now' do
      let(:user) do
        Fabricate(
          :user,
          silenced_till: 1.year.from_now, trust_level: TrustLevel[1]
        )
      end
      subject { described_class.new(user) }

      it 'returns false' do
        expect(subject.should_autosilence?).to eq(false)
      end
    end
  end
end
