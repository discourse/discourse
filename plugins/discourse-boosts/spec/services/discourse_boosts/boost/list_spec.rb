# frozen_string_literal: true

RSpec.describe DiscourseBoosts::Boost::List do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_presence_of(:direction) }
    it { is_expected.to validate_inclusion_of(:direction).in_array(%w[given received]) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :user)
    fab!(:post_author, :user)
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:post) { Fabricate(:post, topic: topic, user: post_author) }
    fab!(:boost) { Fabricate(:boost, post: post, user: acting_user) }

    let(:dependencies) { { guardian: acting_user.guardian } }

    before { SiteSetting.hide_new_user_profiles = false }

    context "when contract is invalid" do
      let(:params) { { username: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when direction is invalid" do
      let(:params) { { username: acting_user.username, direction: "invalid" } }

      it { is_expected.to fail_a_contract }
    end

    context "when target user is not found" do
      let(:params) { { username: "nonexistent_user", direction: "given" } }

      it { is_expected.to fail_to_find_a_model(:target_user) }
    end

    context "with direction: given" do
      let(:params) { { username: acting_user.username, direction: "given" } }

      context "when user cannot see the profile" do
        fab!(:other_user, :user)
        let(:params) { { username: other_user.username, direction: "given" } }

        before do
          SiteSetting.allow_users_to_hide_profile = true
          other_user.user_option.update!(hide_profile_and_presence: true)
        end

        it { is_expected.to fail_a_policy(:can_see_boosts) }
      end

      context "when everything's ok" do
        it { is_expected.to run_successfully }

        it "returns the boosts given by the target user" do
          expect(result[:boosts]).to contain_exactly(boost)
        end

        it "returns boosts in descending ID order" do
          newer_boost = Fabricate(:boost, post: Fabricate(:post, topic: topic), user: acting_user)

          expect(result[:boosts].map(&:id)).to eq([newer_boost.id, boost.id])
        end

        it "limits results to PAGE_SIZE" do
          stub_const(described_class, "PAGE_SIZE", 1) { expect(result[:boosts].length).to eq(1) }
        end

        it "does not return boosts received on the target user's posts" do
          other_post = Fabricate(:post, topic: topic, user: acting_user)
          Fabricate(:boost, post: other_post, user: post_author)
          expect(result[:boosts]).to contain_exactly(boost)
        end

        context "with pagination" do
          fab!(:newer_post) { Fabricate(:post, topic: topic) }
          fab!(:newer_boost) { Fabricate(:boost, post: newer_post, user: acting_user) }

          it "returns only boosts with an ID lower than before_boost_id" do
            result_with_cursor =
              described_class.call(
                params: {
                  username: acting_user.username,
                  direction: "given",
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
          fab!(:inactive_user) { Fabricate(:user, active: false) }
          fab!(:inactive_boost) { Fabricate(:boost, post: post, user: inactive_user) }

          let(:params) { { username: inactive_user.username, direction: "given" } }

          it { is_expected.to fail_to_find_a_model(:target_user) }

          context "when acting user is staff" do
            fab!(:acting_user, :admin)

            it { is_expected.to run_successfully }
          end
        end

        context "when target user is ignored by the viewer" do
          fab!(:viewer, :user)
          let(:dependencies) { { guardian: viewer.guardian } }

          before { Fabricate(:ignored_user, user: viewer, ignored_user: acting_user) }

          it "does not include boosts from ignored users" do
            expect(result[:boosts]).to be_empty
          end

          context "when target user is a staff member" do
            before { acting_user.update!(admin: true) }

            it "still includes boosts from ignored staff" do
              expect(result[:boosts]).to contain_exactly(boost)
            end
          end
        end

        context "when another user views the boosts" do
          fab!(:viewer, :user)
          let(:dependencies) { { guardian: viewer.guardian } }

          it { is_expected.to run_successfully }

          it "returns the boosts given by the target user" do
            expect(result[:boosts]).to contain_exactly(boost)
          end
        end
      end
    end

    context "with direction: received" do
      let(:params) { { username: post_author.username, direction: "received" } }
      let(:dependencies) { { guardian: post_author.guardian } }

      context "when user cannot see notifications" do
        fab!(:other_user, :user)
        let(:dependencies) { { guardian: other_user.guardian } }

        it { is_expected.to fail_a_policy(:can_see_boosts) }
      end

      context "when everything's ok" do
        it { is_expected.to run_successfully }

        it "returns boosts received on the target user's posts" do
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

        it "does not return boosts given by the target user on other users' posts" do
          other_user_post = Fabricate(:post, topic: topic, user: Fabricate(:user))
          Fabricate(:boost, post: other_user_post, user: post_author)
          expect(result[:boosts]).to contain_exactly(boost)
        end

        context "with pagination" do
          fab!(:other_post) { Fabricate(:post, topic: topic, user: post_author) }
          fab!(:newer_boost) { Fabricate(:boost, post: other_post, user: acting_user) }

          it "returns only boosts with an ID lower than before_boost_id" do
            result_with_cursor =
              described_class.call(
                params: {
                  username: post_author.username,
                  direction: "received",
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

        context "when booster is ignored by the viewer" do
          before { Fabricate(:ignored_user, user: post_author, ignored_user: acting_user) }

          it "does not include boosts from ignored users" do
            expect(result[:boosts]).to be_empty
          end

          context "when booster is a staff member" do
            before { acting_user.update!(admin: true) }

            it "still includes boosts from ignored staff" do
              expect(result[:boosts]).to contain_exactly(boost)
            end
          end
        end
      end
    end
  end
end
