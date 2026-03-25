# frozen_string_literal: true

RSpec.describe Appreciations::List do
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

    let(:dependencies) { { guardian: acting_user.guardian } }

    before do
      SiteSetting.hide_new_user_profiles = false
      PostActionCreator.like(acting_user, post)
    end

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

        it { is_expected.to fail_a_policy(:can_see) }
      end

      context "when everything's ok" do
        it { is_expected.to run_successfully }

        it "returns likes given by the target user" do
          appreciations = result[:appreciations]
          expect(appreciations.length).to eq(1)
          expect(appreciations.first.type).to eq("like")
          expect(appreciations.first.post).to eq(post)
          expect(appreciations.first.acting_user).to eq(acting_user)
        end

        it "returns appreciations in descending created_at order" do
          other_post = Fabricate(:post, topic: topic, user: post_author)
          PostActionCreator.like(acting_user, other_post)

          appreciations = result[:appreciations]
          expect(appreciations.length).to eq(2)
          expect(appreciations.first.created_at).to be >= appreciations.last.created_at
        end

        it "limits results to PAGE_SIZE" do
          stub_const(described_class, "PAGE_SIZE", 1) do
            expect(result[:appreciations].length).to eq(1)
          end
        end

        it "does not return likes on the user's own posts" do
          own_post = Fabricate(:post, topic: topic, user: acting_user)
          PostActionCreator.like(post_author, own_post)

          appreciations = result[:appreciations]
          expect(appreciations.length).to eq(1)
          expect(appreciations.first.post).to eq(post)
        end

        context "with pagination" do
          fab!(:newer_post) { Fabricate(:post, topic: topic, user: post_author) }

          before { PostActionCreator.like(acting_user, newer_post) }

          it "returns only appreciations before the given timestamp" do
            all_appreciations = described_class.call(params: params, **dependencies)[:appreciations]
            first_item = all_appreciations.first

            paginated =
              described_class.call(
                params: params.merge(before: first_item.created_at.iso8601(6)),
                **dependencies,
              )

            expect(paginated[:appreciations].length).to eq(1)
            expect(paginated[:appreciations].first.created_at).to be < first_item.created_at
          end
        end

        context "when post is deleted" do
          fab!(:deleted_post) do
            Fabricate(:post, topic: topic, user: post_author, deleted_at: Time.zone.now)
          end

          before do
            PostAction.create!(
              user: acting_user,
              post: deleted_post,
              post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
            )
          end

          it "does not include likes on deleted posts" do
            expect(result[:appreciations].length).to eq(1)
          end
        end

        context "when topic is deleted" do
          fab!(:deleted_topic) { Fabricate(:topic, category: category, deleted_at: Time.zone.now) }
          fab!(:deleted_post) { Fabricate(:post, topic: deleted_topic, user: post_author) }

          before do
            PostAction.create!(
              user: acting_user,
              post: deleted_post,
              post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
            )
          end

          it "does not include likes on deleted topics" do
            expect(result[:appreciations].length).to eq(1)
          end
        end

        context "when filtering by type" do
          let(:params) { { username: acting_user.username, direction: "given", types: "like" } }

          it "returns only the specified type" do
            expect(result[:appreciations].length).to eq(1)
            expect(result[:appreciations].first.type).to eq("like")
          end
        end

        context "when filtering by unknown type" do
          let(:params) { { username: acting_user.username, direction: "given", types: "unknown" } }

          it "returns no results" do
            expect(result[:appreciations]).to be_empty
          end
        end

        context "when target user has an inactive account" do
          fab!(:inactive_user) { Fabricate(:user, active: false) }
          let(:params) { { username: inactive_user.username, direction: "given" } }

          it { is_expected.to fail_to_find_a_model(:target_user) }

          context "when acting user is staff" do
            fab!(:acting_user, :admin)

            it { is_expected.to run_successfully }
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

        it { is_expected.to fail_a_policy(:can_see) }
      end

      context "when everything's ok" do
        it { is_expected.to run_successfully }

        it "returns likes received on the target user's posts" do
          appreciations = result[:appreciations]
          expect(appreciations.length).to eq(1)
          expect(appreciations.first.type).to eq("like")
          expect(appreciations.first.post).to eq(post)
          expect(appreciations.first.acting_user).to eq(acting_user)
        end

        it "does not include likes the target user gave" do
          other_post = Fabricate(:post, topic: topic, user: acting_user)
          PostActionCreator.like(post_author, other_post)

          appreciations = result[:appreciations]
          expect(appreciations.length).to eq(1)
          expect(appreciations.first.acting_user).to eq(acting_user)
        end
      end
    end
  end
end
