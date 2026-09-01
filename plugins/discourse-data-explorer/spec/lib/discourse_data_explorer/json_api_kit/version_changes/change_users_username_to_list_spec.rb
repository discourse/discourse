# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::JsonApiKit::VersionChanges::ChangeUsersUsernameToList do
  it "is dated 2026-07-01 with a client-facing description" do
    expect(described_class.version.to_s).to eq("2026-07-01")
    expect(described_class.description).to include("replaced by `usernames`")
  end

  it "declares the rename for fieldset and pointer lookups" do
    expect(described_class.field_renames_for("users")).to eq(username: :usernames)
  end

  describe "the down transform" do
    subject(:down) { described_class.transform_for(:down, type: "users") }

    context "when the resource carries the list" do
      let(:resource) { { type: :users, attributes: { usernames: %w[sam ninja] } } }

      before { down.call(resource) }

      it "restores the single username, losing the extras" do
        expect(resource[:attributes]).to eq(username: "sam")
      end
    end

    context "when a sparse fieldset excluded the attribute" do
      let(:resource) { { type: :users, attributes: {} } }

      before { down.call(resource) }

      it "leaves the resource untouched" do
        expect(resource[:attributes]).to eq({})
      end
    end
  end

  describe "the up transform" do
    subject(:up) { described_class.transform_for(:up, type: "users") }

    context "when the resource carries the old attribute" do
      let(:resource) { { type: :users, attributes: { username: "sam" } } }

      before { up.call(resource) }

      it "wraps the username in a list" do
        expect(resource[:attributes]).to eq(usernames: %w[sam])
      end
    end
  end
end
