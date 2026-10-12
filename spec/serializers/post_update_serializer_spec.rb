# frozen_string_literal: true

RSpec.describe PostUpdateSerializer do
  fab!(:post)

  describe "#as_json" do
    it "includes the edited body, current draft sequence and visible link counts" do
      user = post.user
      link = Fabricate(:topic_link, post:, clicks: 3)
      sequence = DraftSequence.next!(user, post.topic.draft_key)

      json = described_class.new(post, scope: user.guardian, user:, root: false).as_json

      expect(json[:raw]).to eq(post.raw)
      expect(json[:draft_sequence]).to eq(sequence)
      expect(json[:link_counts]).to contain_exactly(include(url: link.url, clicks: 3))
    end
  end
end
