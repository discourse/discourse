# frozen_string_literal: true

RSpec.describe DraftSequence do
  fab!(:user)
  fab!(:upload)
  let!(:topic_draft_key) { Draft::NEW_TOPIC + "_0001" }

  describe ".next" do
    it "should produce next sequence for a key" do
      expect(DraftSequence.next!(user, topic_draft_key)).to eq 1
      expect(DraftSequence.next!(user, topic_draft_key)).to eq 2
    end

    it "should not produce next sequence for non-human user" do
      user.id = -99_999
      2.times { expect(DraftSequence.next!(user, "test")).to eq(0) }
    end

    it "deletes old drafts and associated upload references" do
      Draft.set(
        user,
        topic_draft_key,
        0,
        {
          reply: "[#{upload.original_filename}|attachment](#{upload.short_url})",
          action: "createTopic",
          title: "New topic with an upload",
          categoryId: 1,
          tags: [],
          archetypeId: "regular",
          metaData: nil,
          composerTime: 10_000,
          typingTime: 10_000,
        }.to_json,
      )

      expect { DraftSequence.next!(user, topic_draft_key) }.to change { Draft.count }.by(
        -1,
      ).and change { UploadReference.count }.by(-1).and change {
                    user.reload.user_stat.draft_count
                  }.by(-1)
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
