# frozen_string_literal: true

RSpec.describe Migration::GroupMentionSlugRewriter do
  def rewrite(text, old_slug, new_slug)
    described_class.rewrite_text(text, old_slug, new_slug)
  end

  describe ".rewrite_text" do
    let(:old_slug) { "anonymous" }
    let(:new_slug) { "anonymous_users" }

    it "rewrites mentions followed by punctuation" do
      expect(rewrite("@anonymous, please", old_slug, new_slug)).to eq("@anonymous_users, please")
    end

    it "rewrites mentions wrapped in parentheses" do
      expect(rewrite("Ping (@anonymous) for help", old_slug, new_slug)).to eq(
        "Ping (@anonymous_users) for help",
      )
    end

    it "rewrites mentions at end of string" do
      expect(rewrite("Thanks @anonymous", old_slug, new_slug)).to eq("Thanks @anonymous_users")
    end

    it "rewrites mentions followed by whitespace" do
      expect(rewrite("Hey @anonymous there", old_slug, new_slug)).to eq(
        "Hey @anonymous_users there",
      )
    end

    it "does not rewrite when the slug is a prefix of a longer mention" do
      expect(rewrite("@anonymous_users", old_slug, new_slug)).to eq("@anonymous_users")
    end

    it "does not rewrite when @ is preceded by a mention character" do
      expect(rewrite("email@anonymous.com", old_slug, new_slug)).to eq("email@anonymous.com")
    end

    context "when renaming a conflicting legacy anonymous_users group" do
      let(:old_slug) { "anonymous_users" }
      let(:new_slug) { "anonymous_users_legacy_42" }

      it "rewrites standalone legacy mentions" do
        expect(rewrite("@anonymous_users, thanks", old_slug, new_slug)).to eq(
          "@anonymous_users_legacy_42, thanks",
        )
      end

      it "does not rewrite a longer slug that merely starts with the old name" do
        expect(rewrite("@anonymous_users_extra", old_slug, new_slug)).to eq(
          "@anonymous_users_extra",
        )
      end
    end
  end
end
