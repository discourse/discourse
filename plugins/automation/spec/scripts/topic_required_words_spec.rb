# frozen_string_literal: true

require 'rails_helper'

describe 'TopicRequiredWords' do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic) }
  let!(:automation) do
    DiscourseAutomation::Automation.create!(
      name: 'Ensure word is present',
      script: 'topic_required_words'
    )
  end

  before do
    automation.create_trigger!(name: 'topic', metadata: {})

    automation.fields.create!(
      component: 'text_list',
      name: 'words',
      metadata: { list: ['#foo', '#bar'] }
    )
  end

  context 'editing/creating a post' do
    before do
      automation.trigger.update_with_params(metadata: { topic_id: topic.id })
    end

    context 'topic has a topic_required_words automation associated' do
      context 'post has at least a required word' do
        it 'validates the post' do
          post_creator = PostCreator.new(user, topic_id: topic.id, raw: 'this is quite cool #foo')
          post = post_creator.create
          expect(post.valid?).to be(true)
        end
      end

      context 'post has no required word' do
        it 'doesn’t validate the post' do
          post_creator = PostCreator.new(user, topic_id: topic.id, raw: 'this is quite cool')
          post = post_creator.create
          expect(post.valid?).to be(false)
        end
      end
    end

    context 'topic has no topic_required_words automation associated' do
      context 'post has no required word' do
        it 'validates the post' do
          no_automation_topic = create_topic
          post_creator = PostCreator.new(user, topic_id: no_automation_topic.id, raw: 'this is quite cool')
          post = post_creator.create
          expect(post.valid?).to be(true)
        end
      end
    end
  end
end
