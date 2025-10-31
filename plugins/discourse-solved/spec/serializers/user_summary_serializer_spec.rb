# frozen_string_literal: true

describe UserSummarySerializer do
  fab!(:user)

  let(:guardian) { Guardian.new }
  let(:user_summary) { UserSummary.new(user, guardian) }
  let(:serializer) { described_class.new(user_summary, scope: guardian, root: false) }

  describe "solved_count" do
    it "uses DiscourseSolved::Queries.solved_count" do
      allow(DiscourseSolved::Queries).to receive(:solved_count).with(user.id).and_return(42)
      expect(serializer.as_json[:solved_count]).to eq(42)
      expect(DiscourseSolved::Queries).to have_received(:solved_count).with(user.id)
    end

    it "returns the correct count" do
      expect(serializer.as_json[:solved_count]).to eq(0)

      topic = Fabricate(:topic)
      Fabricate(:post, topic:)
      post = Fabricate(:post, topic:, user:)
      DiscourseSolved.accept_answer!(post, Discourse.system_user)

      expect(serializer.as_json[:solved_count]).to eq(1)
    end
  end
end
