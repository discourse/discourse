require 'rails_helper'

describe SuggestedTopicSerializer do
  let(:user) { Fabricate(:user) }
  let(:admin) { Fabricate(:admin) }

  describe '#featured_link and #featured_link_root_domain' do
    let(:featured_link) { 'http://meta.discourse.org' }
    let(:topic) { Fabricate(:topic, featured_link: featured_link, category: Fabricate(:category, topic_featured_link_allowed: true)) }
    subject(:json) { SuggestedTopicSerializer.new(topic, scope: Guardian.new(user), root: false).as_json }

    context 'when topic featured link is disable' do
      before do
        SiteSetting.topic_featured_link_enabled = true
        topic
        SiteSetting.topic_featured_link_enabled = false
      end

      it 'should not return featured link attrs' do
        expect(json[:featured_link]).to eq(nil)
        expect(json[:featured_link_root_domain]).to eq(nil)
      end
    end

    context 'when topic featured link is enabled' do
      before do
        SiteSetting.topic_featured_link_enabled = true
      end

      it 'should return featured link attrs' do
        expect(json[:featured_link]).to eq(featured_link)
        expect(json[:featured_link_root_domain]).to eq('discourse.org')
      end
    end
  end

  describe 'hidden tags' do
    let(:topic) { Fabricate(:topic) }
    let(:hidden_tag) { Fabricate(:tag, name: 'hidden') }
    let(:staff_tag_group) { Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name]) }

    before do
      SiteSetting.tagging_enabled = true
      staff_tag_group
      topic.tags << hidden_tag
    end

    it 'returns hidden tag to staff' do
      json = SuggestedTopicSerializer.new(topic, scope: Guardian.new(admin), root: false).as_json
      expect(json[:tags]).to eq([hidden_tag.name])
    end

    it 'does not return hidden tag to non-staff' do
      json = SuggestedTopicSerializer.new(topic, scope: Guardian.new(user), root: false).as_json
      expect(json[:tags]).to eq([])
    end
  end
end
