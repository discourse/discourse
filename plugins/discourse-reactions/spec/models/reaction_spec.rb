# frozen_string_literal: true

require "rails_helper"
require_relative "../fabricators/reaction_fabricator.rb"

describe DiscourseReactions::Reaction do
  before { SiteSetting.discourse_reactions_enabled = true }

  it "knows which reactions are valid" do
    SiteSetting.discourse_reactions_enabled_reactions = "laughing|heart|open_mouth|cry|angry|+1|-1"
    expect(described_class.valid_reactions).to eq(
      %w[laughing heart open_mouth cry angry +1 -1].to_set,
    )
  end

  it "knows the main reaction" do
    SiteSetting.discourse_reactions_reaction_for_like = "+1"
    expect(described_class.main_reaction_id).to eq("+1")
  end

  it "knows the reactions that count as a like, that are not the main reaction" do
    SiteSetting.discourse_reactions_enabled_reactions = "laughing|heart|open_mouth|cry|angry|+1|-1"
    SiteSetting.discourse_reactions_reaction_for_like = "+1"
    SiteSetting.discourse_reactions_excluded_from_like = "angry|-1"
    expect(described_class.reactions_counting_as_like).to eq(
      %w[laughing heart open_mouth cry].to_set,
    )
  end
end
