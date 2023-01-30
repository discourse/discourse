# frozen_string_literal: true

RSpec.describe DraftSequence do
  fab!(:user) { Fabricate(:user) }

  describe ".next" do
    it "should produce next sequence for a key" do
      expect(DraftSequence.next!(user, "test")).to eq 1
      expect(DraftSequence.next!(user, "test")).to eq 2
    end

    it "should not produce next sequence for non-human user" do
      user.id = -99_999
      2.times { expect(DraftSequence.next!(user, "test")).to eq(0) }
    end

    it "updates draft count" do
      Draft.create!(user: user, draft_key: "test", data: {})
      expect(user.reload.user_stat.draft_count).to eq(1)
      expect(DraftSequence.next!(user, "test")).to eq 1
      expect(user.reload.user_stat.draft_count).to eq(0)
    end
  end

  describe ".current" do
    it "should return 0 by default" do
      expect(DraftSequence.current(user, "test")).to eq 0
    end

    it "should return nil for non-human user" do
      user.id = -99_999
      expect(DraftSequence.current(user, "test")).to eq(0)
    end

    it "should return the right sequence" do
      expect(DraftSequence.next!(user, "test")).to eq(1)
      expect(DraftSequence.current(user, "test")).to eq(1)
    end
  end
end
