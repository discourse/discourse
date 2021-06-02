# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe 'PostCreatedEdited' do
  let(:basic_topic_params) { { title: 'hello world topic', raw: 'my name is fred', archetype_id: 1 } }
  fab!(:user) { Fabricate(:user) }
  fab!(:automation) { Fabricate(:automation, trigger: DiscourseAutomation::Triggerable::POST_CREATED_EDITED) }

  context 'editing/creating a post' do
    it 'fires the trigger' do
      post = nil

      output = capture_stdout do
        post = PostCreator.create(user, basic_topic_params)
      end

      expect(output).to include('"kind":"post_created_edited"')
      expect(output).to include('"action":"create"')

      output = capture_stdout do
        post.revise(post.user, raw: 'this is another cool topic')
      end

      expect(output).to include('"kind":"post_created_edited"')
      expect(output).to include('"action":"edit"')
    end

    context 'category is restricted' do
      before do
        automation.upsert_field!('restricted_category', 'category', { category_id: Category.last.id }, target: 'trigger' )
      end

      context 'category is allowed' do
        it 'fires the trigger' do
          output = capture_stdout do
            PostCreator.create(user, basic_topic_params.merge({ category: Category.last.id }))
          end

          expect(output).to include('"kind":"post_created_edited"')
        end
      end

      context 'category is not allowed' do
        it 'doesn’t fire the trigger' do
          output = capture_stdout do
            PostCreator.create(user, basic_topic_params)
          end

          expect(output).to_not include('"kind":"post_created_edited"')
        end
      end
    end
  end
end
