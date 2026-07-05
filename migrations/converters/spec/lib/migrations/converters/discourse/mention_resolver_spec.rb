# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::MentionResolver do
  it "classifies a plain name as a user mention" do
    expect(described_class.new.call("gerhard")).to eq("user")
  end

  it "classifies @all as an all mention" do
    expect(described_class.new.call("all")).to eq("all")
    expect(described_class.new.call("All")).to eq("all")
  end

  describe "here mentions" do
    it "recognizes the default here_mention name" do
      expect(described_class.new.call("here")).to eq("here")
    end

    it "honors a custom here_mention setting value" do
      resolver = described_class.new(here_mention: "staff")

      expect(resolver.call("staff")).to eq("here")
      expect(resolver.call("here")).to eq("user")
    end
  end

  describe "group mentions" do
    subject(:resolver) { described_class.new(group_names: %w[Admins Moderators]) }

    it "recognizes a source group name, case-insensitively" do
      expect(resolver.call("admins")).to eq("group")
      expect(resolver.call("Moderators")).to eq("group")
    end

    it "treats an unknown name as a user mention" do
      expect(resolver.call("gerhard")).to eq("user")
    end
  end
end
