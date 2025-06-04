# frozen_string_literal: true
RSpec.describe ReviewableNoteSerializer do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:reviewable) { Fabricate(:reviewable_flagged_post) }
  fab!(:note) do
    Fabricate(:reviewable_note, reviewable: reviewable, user: admin, content: "Test note content")
  end
  def serialized_note(note, current_user = admin)
    ReviewableNoteSerializer.new(note, scope: Guardian.new(current_user), root: false).as_json
  end
  describe "serialization" do
    let(:json) { serialized_note(note) }
    it "includes basic attributes" do
      expect(json[:id]).to eq(note.id)
      expect(json[:content]).to eq("Test note content")
      expect(json[:created_at]).to be_present
      expect(json[:updated_at]).to be_present
    end
    it "includes user information" do
      expect(json[:user]).to be_present
      expect(json[:user][:id]).to eq(admin.id)
      expect(json[:user][:username]).to eq(admin.username)
    end
  end
end
