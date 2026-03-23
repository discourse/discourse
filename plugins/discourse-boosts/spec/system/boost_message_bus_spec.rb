# frozen_string_literal: true

describe "Boost live updates via MessageBus" do
  fab!(:user_1) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:user_2) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:boost_page) { PageObjects::Pages::Boost.new }

  before { SiteSetting.discourse_boosts_enabled = true }

  it "shows a new boost live to another user viewing the topic" do
    sign_in(user_2)
    topic_page.visit_topic(topic)
    expect(boost_page).to have_no_boosts(post)

    boost =
      DiscourseBoosts::Boost::Create.call(
        params: {
          post_id: post.id,
          raw: "🎉",
        },
        guardian: user_1.guardian,
      ).boost

    expect(boost_page).to have_boost(post)
  end

  it "removes a boost live from another user viewing the topic" do
    boost = Fabricate(:boost, post: post, user: user_1)

    sign_in(user_2)
    topic_page.visit_topic(topic)
    expect(boost_page).to have_boost(post)

    DiscourseBoosts::Boost::Destroy.call(params: { boost_id: boost.id }, guardian: user_1.guardian)

    expect(boost_page).to have_no_boosts(post)
  end
end
