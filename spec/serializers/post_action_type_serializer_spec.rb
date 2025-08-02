# frozen_string_literal: true

RSpec.describe PostActionTypeSerializer do
  subject(:serializer) { described_class.new(post_action_type, scope: Guardian.new, root: false) }

  let(:post_action_type) { PostActionType.find_by(name_key: :inappropriate) }

  describe "#description" do
    before { Discourse.stubs(:base_path).returns("discourse.org") }

    it "returns properly interpolated translation" do
      expect(serializer.description).to match(%r{discourse\.org/guidelines})
    end
  end
end
