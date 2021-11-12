# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe 'FlagPostsOnWords' do
  fab!(:user) { Fabricate(:user) }
  fab!(:category) { Fabricate(:category, user: user) }
  fab!(:topic) { Fabricate(:topic, category_id: category.id) }
  fab!(:automation) { Fabricate(:automation, script: DiscourseAutomation::Scriptable::FLAG_POST_ON_WORDS, trigger: DiscourseAutomation::Triggerable::POST_CREATED_EDITED) }

  before do
    SiteSetting.discourse_automation_enabled = true
    automation.fields.create!(
      component: 'text_list',
      name: 'words',
      metadata: { value: ['foo,bar'] },
      target: 'script'
    )
  end

  context 'editing/creating a post' do
    context 'editing a post' do
      fab!(:post) { Fabricate(:post) }

      context 'post has flagged words' do
        it 'flags the post' do
          post.revise(post.user, raw: 'this is another cool topic foo bar')
          expect(post.reviewable_flag).to be_present
        end
      end

      context 'post has no/not all flagged words' do
        it 'doesn’t flag the post' do
          post.revise(post.user, raw: 'this is another cool topic')
          expect(post.reviewable_flag).to_not be_present

          post.revise(post.user, raw: 'this is another cool bar topic')
          expect(post.reviewable_flag).to_not be_present
        end
      end
    end

    context 'creating a post' do
      context 'post has flagged words' do
        it 'flags the post' do
          post_creator = PostCreator.new(user, topic_id: topic.id, raw: 'this is quite bar cool a very cool foo post')
          post = post_creator.create
          expect(post.reviewable_flag).to be_present
        end
      end

      context 'post has no/not all flagged words' do
        it 'doesn’t flag the post' do
          post_creator = PostCreator.new(user, topic_id: topic.id, raw: 'this is quite cool a very cool post')
          post = post_creator.create
          expect(post.reviewable_flag).to_not be_present

          post_creator = PostCreator.new(user, topic_id: topic.id, raw: 'this is quite cool a foo very cool post')
          post = post_creator.create
          expect(post.reviewable_flag).to_not be_present
        end
      end
    end
  end
end
