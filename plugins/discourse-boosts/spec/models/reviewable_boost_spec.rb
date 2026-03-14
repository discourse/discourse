# frozen_string_literal: true

RSpec.describe DiscourseBoosts::ReviewableBoost do
  fab!(:admin)
  fab!(:user)
  fab!(:post_author, :user)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic, user: post_author) }
  fab!(:boost) { Fabricate(:boost, post: post, user: user) }

  describe "#build_combined_actions" do
    fab!(:reviewable) do
      DiscourseBoosts::ReviewableBoost.needs_review!(
        created_by: admin,
        target: boost,
        reviewable_by_moderator: true,
        payload: {
          boost_cooked: boost.cooked,
        },
      )
    end

    it "builds agree and disagree actions when pending" do
      actions = reviewable.actions_for(admin.guardian)
      agree_bundle = actions.bundles.find { |b| b.id.include?("agree") }
      expect(agree_bundle).to be_present
    end
  end

  describe "#perform_agree_and_delete" do
    fab!(:reviewable) do
      DiscourseBoosts::ReviewableBoost.needs_review!(
        created_by: admin,
        target: boost,
        reviewable_by_moderator: true,
        payload: {
          boost_cooked: boost.cooked,
        },
      )
    end

    it "destroys the boost" do
      boost_id = boost.id
      reviewable.perform(admin, :agree_and_delete)
      expect(DiscourseBoosts::Boost.exists?(boost_id)).to eq(false)
    end
  end

  describe "#perform_disagree" do
    fab!(:reviewable) do
      DiscourseBoosts::ReviewableBoost.needs_review!(
        created_by: admin,
        target: boost,
        reviewable_by_moderator: true,
        payload: {
          boost_cooked: boost.cooked,
        },
      )
    end

    it "keeps the boost" do
      reviewable.perform(admin, :disagree)
      expect(DiscourseBoosts::Boost.exists?(boost.id)).to eq(true)
    end
  end
end
