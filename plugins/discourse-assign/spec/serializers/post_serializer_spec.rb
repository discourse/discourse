# frozen_string_literal: true

require "rails_helper"
require_relative "../support/assign_allowed_group"

describe PostSerializer do
  fab!(:user)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }
  let(:guardian) { Guardian.new(user) }

  include_context "with group that is allowed to assign"

  before do
    SiteSetting.assign_enabled = true
    add_to_assign_allowed_group(user)
  end

  it "includes assigned user in serializer" do
    Assigner.new(post, user).assign(user)
    serializer = PostSerializer.new(post, scope: guardian)
    post = serializer.as_json[:post]
    expect(post[:assigned_to_user][:id]).to eq(user.id)
    expect(post[:assigned_to_group]).to be(nil)
  end

  it "includes assigned group in serializer" do
    Assigner.new(post, user).assign(assign_allowed_group)
    serializer = PostSerializer.new(post, scope: guardian)
    post = serializer.as_json[:post]
    expect(post[:assigned_to_group][:id]).to eq(assign_allowed_group.id)
    expect(post[:assigned_to_user]).to be(nil)
  end

  it "includes note in serializer" do
    Assigner.new(post, user).assign(user, note: "tomtom best")
    serializer = PostSerializer.new(post, scope: guardian)
    expect(serializer.as_json[:post][:assignment_note]).to eq("tomtom best")
  end

  context "when status is enabled" do
    before { SiteSetting.enable_assign_status = true }

    it "includes status in serializer" do
      Assigner.new(post, user).assign(user, status: "Done")
      serializer = PostSerializer.new(post, scope: guardian)
      expect(serializer.as_json[:post][:assignment_status]).to eq("Done")
    end
  end

  context "when status is disabled" do
    before { SiteSetting.enable_assign_status = false }

    it "doesn't include status in serializer" do
      Assigner.new(post, user).assign(user, status: "Done")
      serializer = PostSerializer.new(post, scope: guardian)
      expect(serializer.as_json[:post][:assignment_status]).not_to eq("Done")
    end
  end
end
