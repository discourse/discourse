# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SearchTopicListItemSerializer do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:post) { Fabricate(:post) }
  let(:topic) { post.topic }

  let(:serializer) do
    SearchTopicListItemSerializer.new(topic, scope: Guardian.new(admin), root: false)
  end

  it 'should only include the required keys' do
    current_keys = serializer.as_json.keys

    expected_keys = [
      :id,
      :fancy_title,
      :slug,
      :posts_count,
      :archetype,
      :pinned,
      :unpinned,
      :visible,
      :closed,
      :archived,
      :bookmarked,
      :liked,
      :category_id
    ]

    extra_keys = current_keys - expected_keys
    missing_keys = expected_keys - current_keys

    expect(extra_keys).to eq([]), lambda {
      "Please verify if the following keys are required as part of the serializer's payload: #{extra_keys.join(", ")}"
    }

    expect(missing_keys).to eq([])
  end
end
