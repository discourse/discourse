# frozen_string_literal: true

describe "Composer don't feed the trolls popup", type: :system do
  fab!(:user)
  fab!(:troll, :user)
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:post) { Fabricate(:post, user: user, topic: topic) }
  fab!(:reply) { Fabricate(:post, user: troll, topic: topic) }
  fab!(:flag) { Fabricate(:flag_post_action, post: reply, user: user) }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before { sign_in user }

  it "shows a popup when about to reply to a troll" do
    skip(
      "TGX: This does not work when Capybara.disable_animation is set to true. We're in the midst of fixing this.",
    )

    SiteSetting.educate_until_posts = 0

    topic_page.visit_topic(topic)
    topic_page.click_post_action_button(reply, :reply)

    expect(topic_page).to have_composer_popup_content(I18n.t("education.dont_feed_the_trolls"))
  end
end
