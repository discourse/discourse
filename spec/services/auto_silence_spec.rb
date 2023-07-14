# frozen_string_literal: true

RSpec.describe SpamRule::AutoSilence do
  before do
    SiteSetting.hide_post_sensitivity = Reviewable.sensitivities[:disabled]
    Reviewable.set_priorities(high: 4.0)
    SiteSetting.silence_new_user_sensitivity = Reviewable.sensitivities[:low]
    SiteSetting.num_users_to_silence_new_user = 2
  end

  describe "perform" do
    subject(:autosilence) { described_class.new(post.user) }

    let(:user) { Fabricate.build(:newuser) }
    let(:post) { Fabricate(:post, user: user) }

    it "takes no action if user should not be silenced" do
      autosilence.perform
      expect(post.user.reload).not_to be_silenced
    end

    it "delivers punishment when user should be silenced" do
      Reviewable.set_priorities(high: 2.0)
      SiteSetting.silence_new_user_sensitivity = Reviewable.sensitivities[:low]
      SiteSetting.num_users_to_silence_new_user = 1
      PostActionCreator.spam(Discourse.system_user, post)
      autosilence.perform
      expect(post.user.reload).to be_silenced
    end
  end

  describe "total_spam_score" do
    subject(:score) { enforcer.user_spam_stats.total_spam_score }

    let(:post) { Fabricate(:post) }
    let(:enforcer) { described_class.new(post.user) }
    let(:flagger) { Fabricate(:user) }

    it "returns 0 when there are no flags" do
      expect(score).to eq(0)
    end

    it "returns 0 when there is one flag that has a reason other than spam" do
      PostActionCreator.off_topic(flagger, post)
      expect(score).to eq(0)
    end

    it "returns the score when there are two flags with spam as the reason" do
      PostActionCreator.spam(Fabricate(:user), post)
      PostActionCreator.spam(Fabricate(:user), post)
      expect(score).to eq(4.0)
    end

    it "returns the score when there are two spam flags, each on a different post" do
      PostActionCreator.spam(Fabricate(:user), post)
      PostActionCreator.spam(Fabricate(:user), Fabricate(:post, user: post.user))
      expect(score).to eq(4.0)
    end
  end

  describe "spam_user_count" do
    subject(:count) { enforcer.user_spam_stats.spam_user_count }

    let(:post) { Fabricate(:post) }
    let(:enforcer) { described_class.new(post.user) }

    it "returns 0 when there are no flags" do
      expect(count).to eq(0)
    end

    it "returns 0 when there is one flag that has a reason other than spam" do
      Fabricate(:flag, post: post, post_action_type_id: PostActionType.types[:off_topic])
      expect(count).to eq(0)
    end

    it "returns 1 when there is one spam flag" do
      PostActionCreator.spam(Fabricate(:user), post)
      expect(count).to eq(1)
    end

    it "returns 2 when there are two spam flags from 2 users" do
      PostActionCreator.spam(Fabricate(:user), post)
      PostActionCreator.spam(Fabricate(:user), post)
      expect(count).to eq(2)
    end

    it "returns 1 when there are two spam flags on two different posts from 1 user" do
      flagger = Fabricate(:user)
      PostActionCreator.spam(flagger, post)
      PostActionCreator.spam(flagger, Fabricate(:post, user: post.user))
      expect(count).to eq(1)
    end
  end

  describe "#silence_user" do
    subject(:autosilence) { described_class.new(user) }

    let!(:admin) { Fabricate(:admin) } # needed for SystemMessage
    let(:user) { Fabricate(:user) }
    let!(:post) { Fabricate(:post, user: user) }

    context "when user is not silenced" do
      it "prevents the user from making new posts" do
        autosilence.silence_user
        expect(user).to be_silenced
        expect(Guardian.new(user).can_create_post?(nil)).to be_falsey
      end

      context "with a moderator" do
        let!(:moderator) { Fabricate(:moderator) }

        it "sends private message to moderators" do
          SiteSetting.notify_mods_when_user_silenced = true
          autosilence.silence_user
          expect(autosilence.group_message).to be_present
        end

        it "doesn't send a pm to moderators if notify_mods_when_user_silenced is false" do
          SiteSetting.notify_mods_when_user_silenced = false
          autosilence.silence_user
          expect(autosilence.group_message).to be_blank
        end
      end
    end

    context "when user is already silenced" do
      before { UserSilencer.silence(user) }

      it "doesn't send a pm to moderators if the user is already silenced" do
        autosilence.silence_user
        expect(autosilence.group_message).to be_blank
      end
    end
  end

  describe "autosilenced?" do
    let(:user) { Fabricate(:newuser) }
    let(:flagger) { Fabricate(:user) }
    let(:flagger2) { Fabricate(:user) }
    let(:post) { Fabricate(:post, user: user) }
    let(:post2) { Fabricate(:post, user: user) }

    context "with higher trust levels or staff" do
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

    context "with new user" do
      subject(:autosilence) { described_class.new(user) }

      let(:stats) { autosilence.user_spam_stats }

      it "returns false if there are no spam flags" do
        expect(stats.total_spam_score).to eq(0)
        expect(stats.spam_user_count).to eq(0)
        expect(autosilence.should_autosilence?).to eq(false)
      end

      it "returns false if there are not received enough flags" do
        PostActionCreator.spam(flagger, post)
        expect(stats.total_spam_score).to eq(2.0)
        expect(stats.spam_user_count).to eq(1)
        expect(autosilence.should_autosilence?).to eq(false)
      end

      it "returns false if there have not been enough users" do
        PostActionCreator.spam(flagger, post)
        PostActionCreator.spam(flagger, post2)
        expect(stats.total_spam_score).to eq(4.0)
        expect(stats.spam_user_count).to eq(1)
        expect(autosilence.should_autosilence?).to eq(false)
      end

      it "returns false if silence_new_user_sensitivity is disabled" do
        SiteSetting.silence_new_user_sensitivity = Reviewable.sensitivities[:disabled]
        PostActionCreator.spam(flagger, post)
        PostActionCreator.spam(flagger2, post)
        expect(autosilence.should_autosilence?).to eq(false)
      end

      it "returns false if num_users_to_silence_new_user is 0" do
        SiteSetting.num_users_to_silence_new_user = 0
        PostActionCreator.spam(flagger, post)
        PostActionCreator.spam(flagger2, post)
        expect(autosilence.should_autosilence?).to eq(false)
      end

      it "returns true when there are enough flags from enough users" do
        PostActionCreator.spam(flagger, post)
        PostActionCreator.spam(flagger2, post)
        expect(stats.total_spam_score).to eq(4.0)
        expect(stats.spam_user_count).to eq(2)
        expect(autosilence.should_autosilence?).to eq(true)
      end
    end

    context "when silenced, but has higher trust level now" do
      subject(:autosilence) { described_class.new(user) }

      let(:user) { Fabricate(:user, silenced_till: 1.year.from_now, trust_level: TrustLevel[1]) }

      it "returns false" do
        expect(autosilence.should_autosilence?).to eq(false)
      end
    end
  end
end
