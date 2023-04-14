# frozen_string_literal: true

RSpec.describe UserSummarySerializer do
  it "returns expected data" do
    UserActionManager.enable
    user = Fabricate(:user)
    liked_user = Fabricate(:user, name: "John Doe", username: "john_doe")
    liked_post = create_post(user: liked_user)
    PostActionCreator.like(user, liked_post)

    guardian = Guardian.new(user)
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

    # do not include full name if disabled
    SiteSetting.enable_names = false
    expect(serializer.as_json[:most_liked_users][0][:name]).to eq(nil)
  end

  it "returns correct links data ranking" do
    topic = Fabricate(:topic)
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
