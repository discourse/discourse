# frozen_string_literal: true

require "rails_helper"
require_relative "../fabricators/reaction_fabricator.rb"
require_relative "../fabricators/reaction_user_fabricator.rb"

describe DiscourseReactions::ReactionUser do
  before { SiteSetting.discourse_reactions_enabled = true }

  describe "delegating methods when the user is nil" do
    let(:reaction_user) { described_class.new(user: nil) }

    it "returns nil when delegating the username method with a nil user" do
      expect(reaction_user.username).to be_nil
    end

    it "returns nil when delegating the avatar_template method with a nil user" do
      expect(reaction_user.avatar_template).to be_nil
    end
  end

  describe "when a user gets deleted" do
    it "deletes all the reactions for that user" do
      user = Fabricate(:user)
      reaction = Fabricate(:reaction)
      post = Fabricate(:post)
      user_reaction = Fabricate(:reaction_user, user: user, reaction: reaction, post: post)

      user.destroy!
      reaction_users = described_class.where(user_id: user.id)

      expect(reaction_users).to be_empty
    end
  end
end
