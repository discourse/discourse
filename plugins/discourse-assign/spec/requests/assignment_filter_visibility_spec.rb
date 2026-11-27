# frozen_string_literal: true

RSpec.describe "Assignment filter visibility", type: :request do
  fab!(:admin)
  fab!(:assign_group) { Fabricate(:group, assignable_level: Group::ALIAS_LEVELS[:everyone]) }
  fab!(:reader) { Fabricate(:user, groups: [assign_group]) }
  fab!(:topic) { Fabricate(:topic_with_op, user: admin) }
  fab!(:target) { Fabricate(:post, topic:, user: admin, post_type: Post.types[:whisper]) }

  before do
    SiteSetting.assign_enabled = true
    SiteSetting.assign_allowed_on_groups = assign_group.id.to_s
    SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
    SearchIndexer.enable
    SearchIndexer.index(topic.first_post, force: true)
    Fabricate(:post_assignment, post: target, assigned_to: reader, assigned_by_user: admin)
    sign_in(reader)
    expect(reader.guardian.can_see_topic?(topic)).to eq(true)
    expect(reader.guardian.can_see_post?(target)).to eq(false)
  end

  def list_ids
    expect(response.status).to eq(200)
    response.parsed_body.dig("topic_list", "topics").map { |entry| entry["id"] }
  end

  def search_ids(term)
    get "/search.json", params: { q: term }
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("grouped_search_result", "error")).to be_blank
    response.parsed_body.fetch("topics", []).map { |entry| entry["id"] }
  end

  it "ignores hidden assignments in the assigned TopicQuery filter" do
    ["*", "me", reader.username].each do |name|
      get "/latest.json", params: { assigned: name }
      expect(list_ids).not_to include(topic.id)
    end
    get "/latest.json", params: { assigned: "nobody" }
    expect(list_ids).to include(topic.id)

    sign_in(admin)
    get "/latest.json", params: { assigned: reader.username }
    expect(list_ids).to include(topic.id)
    get "/latest.json", params: { assigned: "nobody" }
    expect(list_ids).not_to include(topic.id)
  end

  it "ignores hidden assignments in custom topic filters" do
    ["*", reader.username].each do |name|
      get "/filter.json", params: { q: "assigned:#{name}" }
      expect(list_ids).not_to include(topic.id)
    end
    get "/filter.json", params: { q: "assigned:nobody" }
    expect(list_ids).to include(topic.id)

    sign_in(admin)
    get "/filter.json", params: { q: "assigned:#{reader.username}" }
    expect(list_ids).to include(topic.id)
  end

  it "ignores hidden assignments in search predicates" do
    expect(search_ids("in:assigned")).not_to include(topic.id)
    expect(search_ids("assigned:#{reader.username}")).not_to include(topic.id)
    expect(search_ids("in:unassigned")).to include(topic.id)

    sign_in(admin)
    expect(search_ids("assigned:#{reader.username}")).to include(topic.id)
    expect(search_ids("in:assigned")).to include(topic.id)
    expect(search_ids("in:unassigned")).not_to include(topic.id)
  end

  it "ignores hidden assignments in user and group assigned lists" do
    get "/topics/messages-assigned/#{reader.username}.json"
    expect(list_ids).not_to include(topic.id)
    get "/topics/group-topics-assigned/#{assign_group.name}.json"
    expect(list_ids).not_to include(topic.id)

    sign_in(admin)
    get "/topics/messages-assigned/#{reader.username}.json"
    expect(list_ids).to include(topic.id)
    get "/topics/group-topics-assigned/#{assign_group.name}.json"
    expect(list_ids).to include(topic.id)
  end

  it "scopes group assignee predicates too" do
    Assignment.find_by!(target:).update!(assigned_to: assign_group)
    get "/latest.json", params: { assigned: assign_group.name }
    expect(list_ids).not_to include(topic.id)
    get "/filter.json", params: { q: "assigned:#{assign_group.name}" }
    expect(list_ids).not_to include(topic.id)
    expect(search_ids("assigned:#{assign_group.name}")).not_to include(topic.id)

    sign_in(admin)
    get "/latest.json", params: { assigned: assign_group.name }
    expect(list_ids).to include(topic.id)
    get "/filter.json", params: { q: "assigned:#{assign_group.name}" }
    expect(list_ids).to include(topic.id)
    expect(search_ids("assigned:#{assign_group.name}")).to include(topic.id)
  end

  it "still matches a visible assignment when the topic also has a hidden assignment" do
    Fabricate(:topic_assignment, topic:, assigned_to: reader, assigned_by_user: admin)
    get "/latest.json", params: { assigned: reader.username }
    expect(list_ids).to include(topic.id)
    get "/filter.json", params: { q: "assigned:#{reader.username}" }
    expect(list_ids).to include(topic.id)
    expect(search_ids("assigned:#{reader.username}")).to include(topic.id)
  end

  it "scopes the post filter's positive and unassigned branches" do
    ["*", reader.username].each do |name|
      posts =
        PostsFilter.new(guardian: reader.guardian).filter_from_query_string("assigned_to:#{name}")
      expect(posts.pluck(:topic_id)).not_to include(topic.id)
    end
    posts =
      PostsFilter.new(guardian: reader.guardian).filter_from_query_string("assigned_to:nobody")
    expect(posts.pluck(:topic_id)).to include(topic.id)
    posts =
      PostsFilter.new(guardian: admin.guardian).filter_from_query_string(
        "assigned_to:#{reader.username}",
      )
    expect(posts.pluck(:topic_id)).to include(topic.id)
  end

  it "scopes private message assigned lists and their count to the viewer, not the assignee" do
    pm = Fabricate(:private_message_topic, user: admin, recipient: reader)
    whisper = Fabricate(:post, topic: pm, user: admin, post_type: Post.types[:whisper])
    Fabricate(:post_assignment, post: whisper, assigned_to: reader, assigned_by_user: admin)

    get "/topics/private-messages-assigned/#{reader.username}.json"
    expect(list_ids).not_to include(pm.id)
    get "/latest.json", params: { assigned: reader.username }
    expect(response.parsed_body.dig("topic_list", "assigned_messages_count")).to eq(0)

    Fabricate(:topic_assignment, topic: pm, assigned_to: reader, assigned_by_user: admin)
    get "/topics/private-messages-assigned/#{reader.username}.json"
    expect(list_ids).to include(pm.id)
    get "/latest.json", params: { assigned: reader.username }
    expect(response.parsed_body.dig("topic_list", "assigned_messages_count")).to eq(1)
  end
end
