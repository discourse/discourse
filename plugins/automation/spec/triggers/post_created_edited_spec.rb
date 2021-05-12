# frozen_string_literal: true

require 'rails_helper'

describe 'POST_CREATED_EDITED' do
  before do
    DiscourseAutomation::Scriptable.add('tag_created_post') do
      version 1

      script do
        p 'Howdy!'
      end
    end
  end

  let(:basic_topic_params) { { title: 'hello world topic', raw: 'my name is fred', archetype_id: 1 } }
  let(:user) { Fabricate(:user) }
  let!(:automation) { DiscourseAutomation::Automation.create!(name: 'Tagging post with content', script: 'tag_created_post', last_updated_by_id: Discourse.system_user.id) }
  let!(:trigger) {
    automation.create_trigger!(name: 'post_created_edited', metadata: { })
  }

  context 'editing/creating a post' do
    it 'fires the trigger' do
      post = nil

      output = capture_stdout do
        post = PostCreator.create(user, basic_topic_params)
      end

      expect(output).to include('Howdy!')

      output = capture_stdout do
        post.revise(post.user, raw: 'this is another cool topic')
      end

      expect(output).to include('Howdy!')
    end
  end
end
