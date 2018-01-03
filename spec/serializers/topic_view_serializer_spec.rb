require 'rails_helper'

describe TopicViewSerializer do
  let(:topic) { Fabricate(:topic) }
  let(:user) { Fabricate(:user) }

  describe '#featured_link and #featured_link_root_domain' do
    let(:featured_link) { 'http://meta.discourse.org' }

    describe 'when topic featured link is disable' do
      it 'should return the right attributes' do
        topic.update!(featured_link: featured_link)
        SiteSetting.topic_featured_link_enabled = false

        topic_view = TopicView.new(topic.id, user)
        json = described_class.new(topic_view, scope: Guardian.new(user), root: false).as_json

        expect(json[:featured_link]).to eq(nil)
        expect(json[:featured_link_root_domain]).to eq(nil)
      end
    end

    describe 'when topic featured link is enabled' do
      it 'should return the right attributes' do
        topic.update!(featured_link: featured_link)

        topic_view = TopicView.new(topic.id, user)
        json = described_class.new(topic_view, scope: Guardian.new(user), root: false).as_json

        expect(json[:featured_link]).to eq(featured_link)
        expect(json[:featured_link_root_domain]).to eq('discourse.org')
      end
    end
  end

  describe '#suggested_topics' do
    let(:topic2) { Fabricate(:topic) }

    before do
      TopicUser.update_last_read(user, topic2.id, 0, 0, 0)
    end

    describe 'when loading last chunk' do
      it 'should include suggested topics' do
        topic_view = TopicView.new(topic.id, user)
        json = described_class.new(topic_view, scope: Guardian.new(user), root: false).as_json

        expect(json[:suggested_topics].first.id).to eq(topic2.id)
      end
    end

    describe 'when not loading last chunk' do
      let(:post) { Fabricate(:post, topic: topic) }
      let(:post2) { Fabricate(:post, topic: topic) }

      it 'should not include suggested topics' do
        post
        post2
        topic_view = TopicView.new(topic.id, user, post_ids: [post.id])
        topic_view.next_page
        json = described_class.new(topic_view, scope: Guardian.new(user), root: false).as_json

        expect(json[:suggested_topics]).to eq(nil)
      end
    end
  end
end
