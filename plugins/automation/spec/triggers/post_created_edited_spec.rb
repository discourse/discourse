# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe 'PostCreatedEdited' do
  before do
    SiteSetting.discourse_automation_enabled = true
  end

  let(:basic_topic_params) { { title: 'hello world topic', raw: 'my name is fred', archetype_id: 1 } }
  fab!(:user) { Fabricate(:user) }
  fab!(:automation) { Fabricate(:automation, trigger: DiscourseAutomation::Triggerable::POST_CREATED_EDITED) }

  context 'editing/creating a post' do
    it 'fires the trigger' do
      post = nil

      output = JSON.parse(capture_stdout do
        post = PostCreator.create(user, basic_topic_params)
      end)

      expect(output['kind']).to eq('post_created_edited')
      expect(output['action']).to eq('create')

      output = JSON.parse(capture_stdout do
        post.revise(post.user, raw: 'this is another cool topic')
      end)

      expect(output['kind']).to eq('post_created_edited')
      expect(output['action']).to eq('edit')
    end

    context 'trust_levels are restricted' do
      before do
        automation.upsert_field!('valid_trust_levels', 'trust-levels', { value: [0] }, target: 'trigger')
      end

      context 'trust level is allowed' do
        it 'fires the trigger' do
          output = JSON.parse(capture_stdout do
            user.trust_level = TrustLevel[0]
            PostCreator.create(user, basic_topic_params)
          end)

          expect(output['kind']).to eq('post_created_edited')
        end
      end

      context 'trust level is not allowed' do
        it 'doesn’t fire the trigger' do
          output = capture_stdout do
            user.trust_level = TrustLevel[1]
            PostCreator.create(user, basic_topic_params)
          end

          expect(output).to be_blank
        end
      end
    end

    context 'category is restricted' do
      before do
        automation.upsert_field!('restricted_category', 'category', { value: Category.first.id }, target: 'trigger')
      end

      context 'category is allowed' do
        it 'fires the trigger' do
          output = JSON.parse(capture_stdout do
            PostCreator.create(user, basic_topic_params.merge({ category: Category.first.id }))
          end)

          expect(output['kind']).to eq('post_created_edited')
        end
      end

      context 'category is not allowed' do
        fab!(:category) { Fabricate(:category) }

        it 'doesn’t fire the trigger' do
          output = capture_stdout do
            PostCreator.create(user, basic_topic_params.merge({ category: category.id }))
          end

          expect(output).to be_blank
        end
      end
    end
  end
end
