# frozen_string_literal: true
#
describe "Topic Map", type: :system do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user, created_at: 1.day.ago) }
  fab!(:original_post) { Fabricate(:post, topic: topic, user: user, created_at: 1.day.ago) }

  fab!(:other_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:last_post_user) { Fabricate(:user, refresh_auto_groups: true) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:topic_map) { PageObjects::Components::TopicMap.new }

  def avatar_url(user, size)
    URI(user.avatar_template_url.gsub("{size}", size.to_s)).path
  end

  it "updates the various topic stats, avatars" do
    freeze_time
    sign_in(user)
    topic_page.visit_topic(topic)

    # topic map only appears after at least 1 reply
    expect(topic_page).to have_no_topic_map
    Fabricate(:post, topic: topic, created_at: 1.day.ago)
    page.refresh
    expect(topic_page).to have_topic_map

    # created avatar display
    expect(topic_map.created_details).to have_selector("img[src=\"#{avatar_url(user, 24)}\"]")
    expect(topic_map.created_relative_date).to eq "1d"

    # replies, user count
    expect {
      Fabricate(:post, topic: topic, user: user, created_at: 1.day.ago)
      sign_in(last_post_user)
      topic_page.visit_topic_and_open_composer(topic)
      topic_page.send_reply("this is a cool-cat post") # fabricating posts doesn't update the last post details
      topic_page.visit_topic(topic)
    }.to change(topic_map, :replies_count).by(2).and change(topic_map, :users_count).by(1)

    #last reply avatar display
    expect(topic_map.last_reply_details).to have_selector(
      "img[src=\"#{avatar_url(last_post_user, 24)}\"]",
    )
    expect(topic_map.last_reply_relative_date).to eq "1m"

    # avatars details with post counts
    Fabricate(:post, topic: topic)
    Fabricate(:post, user: user, topic: topic)
    Fabricate(:post, user: last_post_user, topic: topic)
    page.refresh
    avatars = topic_map.avatars_details
    expect(avatars.length).to eq 3 # max no. of avatars in a collapsed map
    expect(avatars[0]).to have_selector("img[src=\"#{avatar_url(user, 48)}\"]")
    expect(avatars[0].find(".post-count").text).to eq "3"
    expect(avatars[1]).to have_selector("img[src=\"#{avatar_url(last_post_user, 48)}\"]")
    expect(avatars[1].find(".post-count").text).to eq "2"
    expect(avatars[2]).to have_no_css(".post-count")

    topic_map.expand
    expect(topic_map).to have_no_avatars_details_in_map
    expect(topic_map.expanded_map_avatars_details.length).to eq 4

    # views count
    # TODO (martin) Investigate flakiness
    # sign_in(other_user)
    # topic_page.visit_topic(topic)
    # try_until_success { expect(TopicViewItem.count).to eq(2) }
    # page.refresh
    # expect(topic_map.views_count).to eq(2)

    # likes count
    expect(topic_map).to have_no_likes
    topic_page.click_like_reaction_for(original_post)
    expect(topic_map.likes_count).to eq 1
  end
end
