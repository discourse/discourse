# frozen_string_literal: true

require "user_name_suggester"

RSpec.describe UserNameSuggester do
  describe ".suggest" do
    before do
      SiteSetting.min_username_length = 3
      SiteSetting.max_username_length = 15
      SiteSetting.reserved_usernames = ""
    end

    let(:fallback_username) { I18n.t("fallback_username") + "1" }

    it "keeps adding numbers to the username" do
      Fabricate(:user, username: "sam")
      Fabricate(:user, username: "sAm1")
      Fabricate(:user, username: "sam2")
      Fabricate(:user, username: "sam4")

      expect(UserNameSuggester.suggest("saM")).to eq("saM3")
    end

    it "doesn't raise an error on nil username and suggest the fallback username" do
      expect(UserNameSuggester.suggest(nil)).to eq(fallback_username)
    end

    it "doesn't raise an error on integer username" do
      expect(UserNameSuggester.suggest(999)).to eq("999")
    end

    it "corrects weird characters" do
      expect(UserNameSuggester.suggest("Darth%^Vader")).to eq("Darth_Vader")
    end

    it "adds 1 to an existing username" do
      user = Fabricate(:user)
      expect(UserNameSuggester.suggest(user.username)).to eq("#{user.username}1")
    end

    it "adds numbers if it's too short" do
      expect(UserNameSuggester.suggest("a")).to eq("a11")
    end

    it "doesn't suggest anything based on usernames by default" do
      expect(UserNameSuggester.suggest("bob@example.com")).to eq("user1")
    end

    context "with use_email_for_username_and_name_suggestions enabled" do
      before { SiteSetting.use_email_for_username_and_name_suggestions = true }

      it "is able to guess a decent username from an email" do
        expect(UserNameSuggester.suggest("bob@example.com")).to eq("bob")
      end

      it "has a special case for me and i emails" do
        expect(UserNameSuggester.suggest("me@eviltrout.com")).to eq("eviltrout")
        expect(UserNameSuggester.suggest("i@eviltrout.com")).to eq("eviltrout")
      end
    end

    it "shortens very long suggestions" do
      expect(UserNameSuggester.suggest("myreallylongnameisrobinwardesquire")).to eq(
        "myreallylongnam",
      )
    end

    it "makes room for the digit added if the username is too long" do
      User.create(username: "myreallylongnam", email: "fake@discourse.org")
      expect(UserNameSuggester.suggest("myreallylongnam")).to eq("myreallylongna1")
    end

    it "doesn't suggest reserved usernames" do
      SiteSetting.use_email_for_username_and_name_suggestions = true
      SiteSetting.reserved_usernames = "myadmin|steve|steve1"
      expect(UserNameSuggester.suggest("myadmin@hissite.com")).to eq("myadmin1")
      expect(UserNameSuggester.suggest("steve")).to eq("steve2")
    end

    it "doesn't suggest generic usernames" do
      SiteSetting.use_email_for_username_and_name_suggestions = true
      UserNameSuggester::GENERIC_NAMES.each do |name|
        expect(UserNameSuggester.suggest("#{name}@apple.org")).to eq("apple")
      end
    end

    it "replaces the leading character with _ if it is not alphanumeric" do
      expect(UserNameSuggester.suggest("=myname")).to eq("_myname")
    end

    it "allows leading _" do
      expect(UserNameSuggester.suggest("_myname")).to eq("_myname")
    end

    it "removes trailing characters if they are invalid" do
      expect(UserNameSuggester.suggest("myname!^$=")).to eq("myname")
    end

    it "suggest a fallback username if name contains only invalid characters" do
      suggestion = UserNameSuggester.suggest("---")
      expect(suggestion).to eq(fallback_username)
    end

    it "allows dots in the middle" do
      expect(UserNameSuggester.suggest("my.name")).to eq("my.name")
    end

    it "replaces multiple dots in the middle with _" do
      expect(UserNameSuggester.suggest("my..name")).to eq("my_name")
    end

    it "removes leading dots" do
      expect(UserNameSuggester.suggest("..myname")).to eq("myname")
    end

    it "removes trailing dots" do
      expect(UserNameSuggester.suggest("myname..")).to eq("myname")
    end

    it "handles usernames with a sequence of 2 or more special chars" do
      expect(UserNameSuggester.suggest("Darth__Vader")).to eq("Darth_Vader")
      expect(UserNameSuggester.suggest("Darth_-_Vader")).to eq("Darth_Vader")
    end

    it "should handle typical facebook usernames" do
      expect(UserNameSuggester.suggest("roger.nelson.3344913")).to eq("roger.nelson.33")
    end

    it "removes underscore at the end of long usernames that get truncated" do
      expect(UserNameSuggester.suggest("uuuuuuuuuuuuuu_u")).to_not end_with("_")
    end

    it "adds number if it's too short after removing trailing underscore" do
      User.stubs(:username_length).returns(8..8)
      expect(UserNameSuggester.suggest("uuuuuuu_u")).to eq("uuuuuuu1")
    end

    it "preserves current username" do
      # if several users have username "bill" on the external site,
      # they will have usernames bill, bill1, bill2 etc in Discourse:
      Fabricate(:user, username: "bill")
      Fabricate(:user, username: "bill1")
      Fabricate(:user, username: "bill2")
      Fabricate(:user, username: "bill3")
      Fabricate(:user, username: "bill4")

      # the number should be preserved, bill3 should remain bill3
      suggestion = UserNameSuggester.suggest("bill", current_username: "bill3")

      expect(suggestion).to eq "bill3"
    end

    it "skips input made entirely of disallowed characters" do
      SiteSetting.unicode_usernames = false

      input = %w[Πλάτων علي William]
      suggestion = UserNameSuggester.suggest(*input)

      expect(suggestion).to eq "William"
    end

    it "uses the first item if it isn't made entirely of disallowed characters" do
      SiteSetting.unicode_usernames = false

      input = %w[William علي Πλάτων]
      suggestion = UserNameSuggester.suggest(*input)

      expect(suggestion).to eq "William"
    end

    context "with Unicode usernames disabled" do
      before { SiteSetting.unicode_usernames = false }

      it "transliterates some characters" do
        expect(UserNameSuggester.suggest("Jørn")).to eq("Jorn")
      end

      it "uses fallback username if there are Unicode characters only" do
        expect(UserNameSuggester.suggest("طائر")).to eq(fallback_username)
        expect(UserNameSuggester.suggest("πουλί")).to eq(fallback_username)
      end
    end

    context "with Unicode usernames enabled" do
      before { SiteSetting.unicode_usernames = true }

      it "normalizes unicode usernames with Σ to lowercase" do
        expect(UserNameSuggester.suggest('ΣΣ\'"ΣΣ')).to eq("σς_σς")
      end

      it "does not transliterate" do
        expect(UserNameSuggester.suggest("Jørn")).to eq("Jørn")
      end

      it "does not replace Unicode characters" do
        expect(UserNameSuggester.suggest("طائر")).to eq("طائر")
        expect(UserNameSuggester.suggest("πουλί")).to eq("πουλί")
      end

      it "shortens usernames by counting grapheme clusters" do
        SiteSetting.max_username_length = 10
        expect(UserNameSuggester.suggest("बहुत-लंबा-उपयोगकर्ता-नाम")).to eq("बहुत-लंबा-उपयो")
      end

      it "adds numbers if it's too short" do
        expect(UserNameSuggester.suggest("鳥")).to eq("鳥11")

        # grapheme cluster consists of 3 code points
        expect(UserNameSuggester.suggest("য়া")).to eq("য়া11")
      end

      it "normalizes usernames" do
        actual = "Löwe" # NFD, "Lo\u0308we"
        expected = "Löwe" # NFC, "L\u00F6we"

        expect(UserNameSuggester.suggest(actual)).to eq(expected)
      end

      it "does not suggest a username longer than max column size" do
        SiteSetting.max_username_length = 40

        expect(
          UserNameSuggester.suggest(
            "য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া",
          ),
        ).to eq("য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া")
      end

      it "uses allowlist" do
        SiteSetting.allowed_unicode_username_characters = "[äöüßÄÖÜẞ]"

        expect(UserNameSuggester.suggest("πουλί")).to eq(fallback_username)
        expect(UserNameSuggester.suggest("a鳥b")).to eq("a_b")
        expect(UserNameSuggester.suggest("Löwe")).to eq("Löwe")

        SiteSetting.allowed_unicode_username_characters = "[য়া]"
        expect(UserNameSuggester.suggest("aয়াb鳥c")).to eq("aয়াb_c")
      end
    end
  end
end
