require 'rails_helper'
require_dependency 'post_action'

describe TopicListItemSerializer do
  let(:topic) do
    date = Time.zone.now

    Fabricate.build(:topic,
      title: 'test',
      created_at: date - 2.minutes,
      bumped_at: date,
      posters: [],
    )
  end

  it "correctly serializes topic" do
    SiteSetting.topic_featured_link_enabled = true
    serialized = TopicListItemSerializer.new(topic, scope: Guardian.new, root: false).as_json

    expect(serialized[:title]).to eq("test")
    expect(serialized[:bumped]).to eq(true)
    expect(serialized[:featured_link]).to eq(nil)
    expect(serialized[:featured_link_root_domain]).to eq(nil)

    featured_link = 'http://meta.discourse.org'
    topic.featured_link = featured_link
    serialized = TopicListItemSerializer.new(topic, scope: Guardian.new, root: false).as_json

    expect(serialized[:featured_link]).to eq(featured_link)
    expect(serialized[:featured_link_root_domain]).to eq('discourse.org')
  end

  describe 'when topic featured link is disable' do
    before do
      SiteSetting.topic_featured_link_enabled = false
    end

    it "should not include the topic's featured link" do
      topic.featured_link = 'http://meta.discourse.org'
      serialized = TopicListItemSerializer.new(topic, scope: Guardian.new, root: false).as_json

      expect(serialized[:featured_link]).to eq(nil)
      expect(serialized[:featured_link_root_domain]).to eq(nil)
    end
  end

  describe 'hidden tags' do
    let(:admin) { Fabricate(:admin) }
    let(:user) { Fabricate(:user) }
    let(:hidden_tag) { Fabricate(:tag, name: 'hidden') }
    let(:staff_tag_group) { Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name]) }

    before do
      SiteSetting.tagging_enabled = true
      staff_tag_group
      topic.tags << hidden_tag
    end

    it 'returns hidden tag to staff' do
      json = TopicListItemSerializer.new(topic,
        scope: Guardian.new(admin),
        root: false
      ).as_json

      expect(json[:tags]).to eq([hidden_tag.name])
    end

    it 'does not return hidden tag to non-staff' do
      json = TopicListItemSerializer.new(topic,
        scope: Guardian.new(user),
        root: false
      ).as_json

      expect(json[:tags]).to eq([])
    end

    it 'accepts an option to remove hidden tags' do
      json = TopicListItemSerializer.new(topic,
        scope: Guardian.new(user),
        hidden_tag_names: [hidden_tag.name],
        root: false
      ).as_json

      expect(json[:tags]).to eq([])
    end
  end
end
