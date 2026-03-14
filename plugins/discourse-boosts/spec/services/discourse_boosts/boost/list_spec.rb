# frozen_string_literal: true

RSpec.describe DiscourseBoosts::Boost::List do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:username) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :user)
    fab!(:post_author, :user)
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:post) { Fabricate(:post, topic: topic, user: post_author) }
    fab!(:boost) { Fabricate(:boost, post: post, user: acting_user) }

    let(:params) { { username: post_author.username } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    before { SiteSetting.hide_new_user_profiles = false }

    context "when contract is invalid" do
      let(:params) { { username: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when target user is not found" do
      let(:params) { { username: "nonexistent_user" } }

      it { is_expected.to fail_to_find_a_model(:target_user) }
    end

    context "when user cannot see the profile" do
      before do
        SiteSetting.allow_users_to_hide_profile = true
        post_author.user_option.update!(hide_profile_and_presence: true)
      end

      it { is_expected.to fail_a_policy(:can_see_profile) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "returns the boosts" do
        expect(result[:boosts]).to contain_exactly(boost)
      end

      it "returns boosts in descending ID order" do
        other_post = Fabricate(:post, topic: topic, user: post_author)
        newer_boost = Fabricate(:boost, post: other_post, user: acting_user)

        expect(result[:boosts].map(&:id)).to eq([newer_boost.id, boost.id])
      end

      it "limits results to PAGE_SIZE" do
        stub_const(described_class, "PAGE_SIZE", 1) { expect(result[:boosts].length).to eq(1) }
      end

      context "with pagination" do
        fab!(:other_post) { Fabricate(:post, topic: topic, user: post_author) }
        fab!(:newer_boost) { Fabricate(:boost, post: other_post, user: acting_user) }

        it "returns only boosts with an ID lower than before_boost_id" do
          result_with_cursor =
            described_class.call(
              params: {
                username: post_author.username,
                before_boost_id: newer_boost.id,
              },
              **dependencies,
            )
          expect(result_with_cursor[:boosts]).to contain_exactly(boost)
        end
      end

      context "when post is in a private message" do
        fab!(:pm_topic, :private_message_topic)
        fab!(:pm_post) { Fabricate(:post, topic: pm_topic, user: post_author) }
        fab!(:pm_boost) { Fabricate(:boost, post: pm_post, user: acting_user) }

        it "does not include boosts on private messages" do
          expect(result[:boosts]).to contain_exactly(boost)
        end
      end

      context "when post is in an unlisted topic" do
        fab!(:unlisted_topic) { Fabricate(:topic, category: category, visible: false) }
        fab!(:unlisted_post) { Fabricate(:post, topic: unlisted_topic, user: post_author) }
        fab!(:unlisted_boost) { Fabricate(:boost, post: unlisted_post, user: acting_user) }

        it "does not include boosts on unlisted topics" do
          expect(result[:boosts]).to contain_exactly(boost)
        end
      end

      context "when post is a whisper" do
        fab!(:whisper_post) do
          Fabricate(:post, topic: topic, user: post_author, post_type: Post.types[:whisper])
        end
        fab!(:whisper_boost) { Fabricate(:boost, post: whisper_post, user: acting_user) }

        it "does not include boosts on whispers" do
          expect(result[:boosts]).to contain_exactly(boost)
        end
      end

      context "when post is deleted" do
        fab!(:deleted_post) do
          Fabricate(:post, topic: topic, user: post_author, deleted_at: Time.zone.now)
        end
        fab!(:deleted_post_boost) { Fabricate(:boost, post: deleted_post, user: acting_user) }

        it "does not include boosts on deleted posts" do
          expect(result[:boosts]).to contain_exactly(boost)
        end
      end

      context "when topic is deleted" do
        fab!(:deleted_topic) { Fabricate(:topic, category: category, deleted_at: Time.zone.now) }
        fab!(:deleted_topic_post) { Fabricate(:post, topic: deleted_topic, user: post_author) }
        fab!(:deleted_topic_boost) do
          Fabricate(:boost, post: deleted_topic_post, user: acting_user)
        end

        it "does not include boosts on deleted topics" do
          expect(result[:boosts]).to contain_exactly(boost)
        end
      end

      context "when post is in a restricted category" do
        fab!(:restricted_category) { Fabricate(:private_category, group: Fabricate(:group)) }
        fab!(:restricted_topic) { Fabricate(:topic, category: restricted_category) }
        fab!(:restricted_post) { Fabricate(:post, topic: restricted_topic, user: post_author) }
        fab!(:restricted_boost) { Fabricate(:boost, post: restricted_post, user: acting_user) }

        it "does not include boosts on topics in restricted categories" do
          expect(result[:boosts]).to contain_exactly(boost)
        end
      end

      context "when target user has an inactive account" do
        before { post_author.update!(active: false) }

        it { is_expected.to fail_to_find_a_model(:target_user) }

        context "when acting user is staff" do
          fab!(:acting_user, :admin)

          it { is_expected.to run_successfully }
        end
      end

      context "when acting user views their own boosts" do
        let(:params) { { username: acting_user.username } }

        fab!(:own_post) { Fabricate(:post, topic: topic, user: acting_user) }
        fab!(:own_boost) { Fabricate(:boost, post: own_post, user: post_author) }

        it { is_expected.to run_successfully }

        it "returns boosts on the acting user's posts" do
          expect(result[:boosts]).to contain_exactly(own_boost)
        end
      end
    end
  end
end
