# frozen_string_literal: true

require 'rails_helper'

describe TopicLinkSerializer do

  it "correctly serializes the topic link" do
    post = Fabricate(:post, raw: 'https://meta.discourse.org/')
    TopicLink.extract_from(post)
    serialized = described_class.new(post.topic_links.first, root: false).as_json

    expect(serialized[:domain]).to eq("meta.discourse.org")
    expect(serialized[:root_domain]).to eq("discourse.org")
  end
end
