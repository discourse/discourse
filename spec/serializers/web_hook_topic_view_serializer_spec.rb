# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WebHookTopicViewSerializer do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:topic) { Fabricate(:topic) }

  let(:serializer) do
    WebHookTopicViewSerializer.new(TopicView.new(topic),
      scope: Guardian.new(admin),
      root: false
    )
  end

  before do
    SiteSetting.tagging_enabled = true
  end

  it 'should only include the keys that are sent out in the webhook' do
    expected_keys = %i{
      id
      title
      fancy_title
      posts_count
      created_at
      views
      reply_count
      like_count
      last_posted_at
      visible
      closed
      archived
      archetype
      slug
      category_id
      word_count
      deleted_at
      user_id
      featured_link
      pinned_globally
      pinned_at
      pinned_until
      unpinned
      pinned
      highest_post_number
      deleted_by
      bookmarked
      participant_count
      created_by
      last_poster
      tags
    }

    keys = serializer.as_json.keys

    expect(serializer.as_json.keys).to contain_exactly(*expected_keys)
  end
end
