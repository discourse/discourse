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
end
