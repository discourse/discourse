# frozen_string_literal: true

RSpec.describe DiscourseBoosts::Boost::List do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:username) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :user)
    fab!(:post_author, :user)
    fab!(:topic)
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

      context "with pagination" do
        fab!(:newer_boost) { Fabricate(:boost, post: post, user: acting_user) }

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
