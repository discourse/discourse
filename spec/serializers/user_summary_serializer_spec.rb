# frozen_string_literal: true

RSpec.describe UserSummarySerializer do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:another_user) { Fabricate(:user, refresh_auto_groups: true) }

  it "returns expected data" do
    UserActionManager.enable
    liked_user = Fabricate(:user, name: "John Doe", username: "john_doe", refresh_auto_groups: true)
    liked_post = create_post(user: liked_user)
    PostActionCreator.like(user, liked_post)

    guardian = Guardian.new(another_user)
    summary = UserSummary.new(user, guardian)
    serializer = UserSummarySerializer.new(summary, scope: guardian, root: false)
    json = serializer.as_json

    expect(json[:likes_given]).to eq(1)
    expect(json[:likes_received]).to be_present
    expect(json[:posts_read_count]).to be_present
    expect(json[:topic_count]).to be_present
    expect(json[:time_read]).to be_present
    expect(json[:most_liked_users][0][:count]).to eq(1)
    expect(json[:most_liked_users][0][:name]).to eq("John Doe")
    expect(json[:most_liked_users][0][:username]).to eq("john_doe")
    expect(json[:most_liked_users][0][:avatar_template]).to eq(liked_user.avatar_template)
    expect(json[:can_see_user_actions]).to eq(true)

    # do not include full name if disabled
    SiteSetting.enable_names = false
    expect(serializer.as_json[:most_liked_users][0][:name]).to eq(nil)
  end

  it "respects hide_user_activity_tab setting" do
    SiteSetting.hide_user_activity_tab = true
    guardian = Guardian.new(another_user)
    summary = UserSummary.new(user, guardian)
    serializer = UserSummarySerializer.new(summary, scope: guardian, root: false)

    expect(serializer.as_json[:can_see_user_actions]).to eq(false)
  end

  it "returns correct links data ranking" do
    topic = Fabricate(:topic, user: Fabricate(:user, refresh_auto_groups: true))
    post = Fabricate(:post_with_external_links, user: topic.user, topic: topic)
    TopicLink.extract_from(post)
    TopicLink
      .where(topic_id: topic.id)
      .order(domain: :asc, url: :asc)
      .each_with_index do |link, index|
        index.times do |i|
          TopicLinkClick.create(topic_link: link, ip_address: "192.168.1.#{i + 1}")
        end
      end

    guardian = Guardian.new
    summary = UserSummary.new(topic.user, guardian)
    serializer = UserSummarySerializer.new(summary, scope: guardian, root: false)
    json = serializer.as_json

    expect(json[:links][0][:url]).to eq("http://www.codinghorror.com/blog")
    expect(json[:links][0][:clicks]).to eq(6)
    expect(json[:links][1][:url]).to eq("http://twitter.com")
    expect(json[:links][1][:clicks]).to eq(5)
    expect(json[:links][2][:url]).to eq("https://google.com")
    expect(json[:links][2][:clicks]).to eq(4)
  end
end
