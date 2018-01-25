require 'rails_helper'

describe SuggestedTopicSerializer do
  let(:user) { Fabricate(:user) }

  describe '#featured_link and #featured_link_root_domain' do
    let(:featured_link) { 'http://meta.discourse.org' }
    let(:topic) { Fabricate(:topic, featured_link: featured_link, category: Fabricate(:category, topic_featured_link_allowed: true)) }
    subject(:json) { described_class.new(topic, scope: Guardian.new(user), root: false).as_json }

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
end
