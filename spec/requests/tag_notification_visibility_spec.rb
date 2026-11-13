# frozen_string_literal: true

RSpec.describe "Tag notification preferences for hidden tags" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:hidden_tag) { Fabricate(:tag, name: "hidden-tag") }
  fab!(:topic)
  fab!(:hidden_topic) { Fabricate(:topic, tags: [hidden_tag]) }

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.remove_muted_tags_from_latest = "always"
    Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
    sign_in(user)
  end

  def topic_ids
    response.parsed_body["topic_list"]["topics"].map { |t| t["id"] }
  end

  it "does not reveal hidden tagged topics through muted tags" do
    put "/u/#{user.username}.json", params: { muted_tags: hidden_tag.name }

    expect(response.status).to eq(200)
    expect(TagUser.where(user: user, tag: hidden_tag)).to be_empty

    get "/latest.json"
    expect(response.status).to eq(200)
    expect(topic_ids).to contain_exactly(topic.id, hidden_topic.id)
  end

  it "does not reveal hidden tagged topics through tracked tags" do
    put "/u/#{user.username}.json", params: { tracked_tags: hidden_tag.name }

    expect(response.status).to eq(200)
    expect(TagUser.where(user: user, tag: hidden_tag)).to be_empty

    get "/latest.json", params: { f: "tracked" }
    expect(response.status).to eq(200)
    expect(topic_ids).to be_empty
  end

  it "ignores existing muted preferences for hidden tags" do
    TagUser.create!(
      user: user,
      tag: hidden_tag,
      notification_level: TagUser.notification_levels[:muted],
    )

    get "/latest.json"
    expect(response.status).to eq(200)
    expect(topic_ids).to contain_exactly(topic.id, hidden_topic.id)
  end

  it "ignores existing tracked preferences for hidden tags" do
    TagUser.create!(
      user: user,
      tag: hidden_tag,
      notification_level: TagUser.notification_levels[:tracking],
    )

    get "/latest.json", params: { f: "tracked" }
    expect(response.status).to eq(200)
    expect(topic_ids).to be_empty
  end

  it "still applies notification preferences for tags the user can see" do
    visible_tag = Fabricate(:tag, name: "visible-tag")
    visible_topic = Fabricate(:topic, tags: [visible_tag])

    put "/u/#{user.username}.json", params: { muted_tags: visible_tag.name }

    expect(response.status).to eq(200)
    expect(TagUser.where(user: user, tag: visible_tag)).to be_present

    get "/latest.json"
    expect(response.status).to eq(200)
    expect(topic_ids).to contain_exactly(topic.id, hidden_topic.id)
    expect(topic_ids).not_to include(visible_topic.id)
  end
end
