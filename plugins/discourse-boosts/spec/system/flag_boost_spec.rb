# frozen_string_literal: true

describe "Flagging a boost" do
  fab!(:flagger) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:moderator)
  fab!(:boost_author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic, user: boost_author) }
  fab!(:boost) { Fabricate(:boost, post: post, user: boost_author) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:boost_page) { PageObjects::Pages::Boost.new }
  let(:flag_modal) { PageObjects::Modals::Flag.new }
  let(:review_page) { PageObjects::Pages::Review.new }

  before { SiteSetting.discourse_boosts_enabled = true }

  it "allows flagging a boost and having a moderator agree and delete it" do
    sign_in(flagger)

    topic_page.visit_topic(topic)
    boost_page.click_boost_cooked(post)
    boost_page.click_flag_boost(post)

    flag_modal.choose_type(:off_topic)
    flag_modal.confirm_flag

    expect(boost_page).to have_boost(post)

    reviewable = DiscourseBoosts::ReviewableBoost.find_by(target: boost)

    sign_in(moderator)

    review_page.visit_reviewable(reviewable)

    review_page.select_bundled_action(
      reviewable,
      I18n.t("discourse_boosts.reviewables.actions.agree_and_delete.title"),
      bundle_index: 1,
    )

    expect(review_page).to have_reviewable_with_approved_status(reviewable)

    sign_in(flagger)

    topic_page.visit_topic(topic)

    expect(boost_page).to have_no_boosts(post)
  end
end
