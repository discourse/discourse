# frozen_string_literal: true

RSpec.describe UsernameValidator do
  def expect_valid(*usernames, failure_reason: "")
    usernames.each do |username|
      validator = UsernameValidator.new(username)

      message = "expected '#{username}' to be valid"
      message = "#{message}, #{failure_reason}" if failure_reason.present?
      aggregate_failures do
        expect(validator.valid_format?).to eq(true), message
        expect(validator.errors).to be_empty
      end
    end
  end

  def expect_invalid(*usernames, error_message:, failure_reason: "")
    usernames.each do |username|
      validator = UsernameValidator.new(username)

      message = "expected '#{username}' to be invalid"
      message = "#{message}, #{failure_reason}" if failure_reason.present?
      aggregate_failures do
        expect(validator.valid_format?).to eq(false), message
        expect(validator.errors).to include(error_message)
      end
    end
  end

  let(:max_username_length) do
    [
      User.maximum("length(username)"),
      MaxUsernameLengthValidator::MAX_USERNAME_LENGTH_RANGE.begin,
    ].max
  end
  let(:min_username_length) { User.minimum("length(username)") }

  shared_examples "ASCII username" do
    it "is invalid when the username is blank" do
      expect_invalid("", error_message: I18n.t(:"user.username.blank"))
    end

    it "is invalid when the username is too short" do
      SiteSetting.min_username_length = min_username_length

      usernames = min_username_length.times.map { |i| "a" * i }.filter(&:present?)

      expect_invalid(
        *usernames,
        error_message: I18n.t(:"user.username.short", count: min_username_length),
      )
    end

    it "is valid when the username has the minimum length" do
      SiteSetting.min_username_length = min_username_length

      expect_valid("a" * min_username_length)
    end

    it "is invalid when the username is too long" do
      SiteSetting.max_username_length = max_username_length

      expect_invalid(
        "a" * (max_username_length + 1),
        error_message: I18n.t(:"user.username.long", count: max_username_length),
        failure_reason: "Should be invalid as username length > #{max_username_length}",
      )
    end

    it "is valid when the username has the maximum length" do
      SiteSetting.max_username_length = max_username_length

      expect_valid(
        "a" * max_username_length,
        failure_reason: "Should be valid as username length = #{max_username_length}",
      )
    end

    it "is valid when the username contains alphanumeric characters, dots, underscores and dashes" do
      expect_valid("ab-cd.123_ABC-xYz")
    end

    it "is invalid when the username contains non-alphanumeric characters other than dots, underscores and dashes" do
      expect_invalid("abc|", "a#bc", "abc xyz", error_message: I18n.t(:"user.username.characters"))
    end

    it "is valid when the username starts with a alphanumeric character or underscore" do
      expect_valid("abcd", "1abc", "_abc")
    end

    it "is invalid when the username starts with a dot or dash" do
      expect_invalid(
        ".abc",
        "-abc",
        error_message: I18n.t(:"user.username.must_begin_with_alphanumeric_or_underscore"),
      )
    end

    it "is valid when the username ends with a alphanumeric character" do
      expect_valid("abcd", "abc9")
    end

    it "is invalid when the username ends with an underscore, a dot or dash" do
      expect_invalid(
        "abc_",
        "abc.",
        "abc-",
        error_message: I18n.t(:"user.username.must_end_with_alphanumeric"),
      )
    end

    it "is invalid when the username contains consecutive underscores, dots or dashes" do
      expect_invalid(
        "a__bc",
        "a..bc",
        "a--bc",
        error_message: I18n.t(:"user.username.must_not_contain_two_special_chars_in_seq"),
      )
    end

    it "is invalid when the username ends with certain file extensions" do
      expect_invalid(
        "abc.json",
        "abc.png",
        error_message: I18n.t(:"user.username.must_not_end_with_confusing_suffix"),
      )
    end
  end

  context "when Unicode usernames are disabled" do
    before { SiteSetting.unicode_usernames = false }

    include_examples "ASCII username"

    it "is invalid when the username contains non-ASCII characters except dots, underscores and dashes" do
      expect_invalid("abcö", "abc象", error_message: I18n.t(:"user.username.characters"))
    end
  end

  context "when Unicode usernames are enabled" do
    before { SiteSetting.unicode_usernames = true }

    context "with ASCII usernames" do
      include_examples "ASCII username"
    end

    context "with Unicode usernames" do
      before { SiteSetting.min_username_length = 1 }

      it "is invalid when the username is too short" do
        SiteSetting.min_username_length = min_username_length

        usernames = min_username_length.times.map { |i| "鳥" * i }.filter(&:present?)

        expect_invalid(
          *usernames,
          error_message: I18n.t(:"user.username.short", count: min_username_length),
        )
      end

      it "is valid when the username has the minimum length" do
        SiteSetting.min_username_length = min_username_length

        expect_valid("ط" * min_username_length)
      end

      it "is invalid when the username is too long" do
        SiteSetting.max_username_length = max_username_length

        expect_invalid(
          "ם" * (max_username_length + 1),
          "äl" * (max_username_length + 1),
          error_message: I18n.t(:"user.username.long", count: max_username_length),
          failure_reason: "Should be invalid as username length are > #{max_username_length}",
        )
      end

      it "is valid when the username has the maximum length" do
        SiteSetting.max_username_length = max_username_length

        expect_valid(
          "Д" * max_username_length,
          "س" * max_username_length,
          "மி" * max_username_length,
          failure_reason: "Should be valid as usernames are <= #{max_username_length}",
        )
      end

      it "is invalid when the username has too many Unicode codepoints" do
        SiteSetting.max_username_length = 30

        expect_invalid(
          "য়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়া",
          error_message: I18n.t(:"user.username.too_long"),
        )
      end

      it "is valid when the username contains Unicode letters" do
        expect_valid(
          "鳥",
          "طائر",
          "թռչուն",
          "πουλί",
          "পাখি",
          "madár",
          "새",
          "پرنده",
          "птица",
          "fågel",
          "นก",
          "پرندے",
          "ציפור",
        )
      end

      it "is valid when the username contains numbers from the Nd or Nl Unicode category" do
        expect_valid("arabic٠١٢٣٤٥٦٧٨٩", "bengali০১২৩৪৫৬৭৮৯", "romanⅥ", "hangzhou〺")
      end

      it "is invalid when the username contains numbers from the No Unicode category" do
        expect_invalid("circled㊸", "fraction¾", error_message: I18n.t(:"user.username.characters"))
      end

      it "is invalid when the username contains symbols or emojis" do
        SiteSetting.min_username_length = 1

        expect_invalid(
          "©",
          "⇨",
          "“",
          "±",
          "‿",
          "😃",
          "🚗",
          error_message: I18n.t(:"user.username.characters"),
        )
      end

      it "is invalid when the username contains invisible characters" do
        expect_invalid(
          "a\u{034F}b",
          "a\u{115F}b",
          "a\u{1160}b",
          "a\u{17B4}b",
          "a\u{17B5}b",
          "a\u{180B}b",
          "a\u{180C}b",
          "a\u{180D}b",
          "a\u{3164}b",
          "a\u{FFA0}b",
          "a\u{FE00}b",
          "a\u{FE0F}b",
          "a\u{E0100}b",
          "a\u{E01EF}b",
          error_message: I18n.t(:"user.username.characters"),
        )
      end

      it "is invalid when the username contains zero width join characters" do
        expect_invalid("ണ്‍", "র‌্যাম", error_message: I18n.t(:"user.username.characters"))
      end

      it "is valid when the username ends with a Unicode Mark" do
        expect_valid("தமிழ்")
      end

      it "allows all Unicode letters when the allowlist is empty" do
        expect_valid("鳥")
      end

      context "with Unicode allowlist" do
        before { SiteSetting.allowed_unicode_username_characters = "[äöüÄÖÜß]" }

        it "is invalid when username contains non-allowlisted letters" do
          expect_invalid("鳥", "francès", error_message: I18n.t(:"user.username.characters"))
        end

        it "is valid when username contains only allowlisted letters" do
          expect_valid("Löwe", "Ötzi")
        end

        it "is valid when username contains only ASCII letters and numbers regardless of allowlist" do
          expect_valid("a-z_A-Z.0-9")
        end

        it "is valid after resetting the site setting" do
          SiteSetting.allowed_unicode_username_characters = ""
          expect_valid("鳥")
        end
      end
    end
  end

  describe "#perform_validation" do
    let!(:invalid_username) { "invalidusername" }
    let!(:plugin) { Plugin::Instance.new }
    let!(:modifier) { :username_validation }
    let!(:add_error_block) do
      Proc.new do |errors, context|
        errors << "Plugin validation error message" if context.username == invalid_username
      end
    end

    it "applies plugin modifiers for username validation" do
      expect_valid(invalid_username, failure_reason: "Plugin validations should be called")

      DiscoursePluginRegistry.register_modifier(plugin, modifier, &add_error_block)

      expect_invalid(
        invalid_username,
        error_message: "Plugin validation error message",
        failure_reason: "Plugin validations should be called",
      )
    ensure
      DiscoursePluginRegistry.unregister_modifier(plugin, modifier, &add_error_block)
    end
  end

  describe "watched words validation" do
    after { WatchedWord.destroy_all }

    it "is invalid when username contains a blocked watched word" do
      WatchedWord.create!(word: "blocked", action: WatchedWord.actions[:block])

      expect_invalid(
        "blocked",
        error_message: I18n.t(:"user.username.contains_blocked_word", word: "blocked"),
      )
    end

    it "is invalid when username contains a blocked watched word with wildcard" do
      WatchedWord.create!(word: "*bad*", action: WatchedWord.actions[:block])

      validator = UsernameValidator.new("bad")
      expect(validator.valid_format?).to eq(false)
      expect(validator.errors.first).to include("blocked word")

      validator = UsernameValidator.new("bad_user")
      expect(validator.valid_format?).to eq(false)
      expect(validator.errors.first).to include("blocked word")

      validator = UsernameValidator.new("mybadname")
      expect(validator.valid_format?).to eq(false)
      expect(validator.errors.first).to include("blocked word")
    end

    it "is invalid when username contains a censored watched word" do
      WatchedWord.create!(word: "*censor*", action: WatchedWord.actions[:censor])

      expect_invalid(
        "censor_user",
        error_message: I18n.t(:"user.username.contains_blocked_word", word: "censor_user"),
      )
    end

    it "is invalid when username contains a flagged watched word" do
      WatchedWord.create!(word: "*flag*", action: WatchedWord.actions[:flag])

      expect_invalid(
        "flag_user",
        error_message: I18n.t(:"user.username.contains_blocked_word", word: "flag_user"),
      )
    end

    it "is invalid when username contains a silenced watched word" do
      WatchedWord.create!(word: "*silence*", action: WatchedWord.actions[:silence])

      expect_invalid(
        "silence_user",
        error_message: I18n.t(:"user.username.contains_blocked_word", word: "silence_user"),
      )
    end

    it "is invalid when username contains a require approval watched word" do
      WatchedWord.create!(word: "*approve*", action: WatchedWord.actions[:require_approval])

      expect_invalid(
        "approve_user",
        error_message: I18n.t(:"user.username.contains_blocked_word", word: "approve_user"),
      )
    end

    it "is invalid when username contains multiple watched words" do
      WatchedWord.create!(word: "*bad*", action: WatchedWord.actions[:block])
      WatchedWord.create!(word: "*evil*", action: WatchedWord.actions[:block])

      validator = UsernameValidator.new("bad_evil_user")
      expect(validator.valid_format?).to eq(false)
      expect(validator.errors.first).to include("blocked word")
    end

    it "is valid when username does not contain any watched words" do
      WatchedWord.create!(word: "*bad*", action: WatchedWord.actions[:block])

      expect_valid("gooduser", "nice_name")
    end

    it "is invalid when username matches watched word with word boundaries" do
      WatchedWord.create!(word: "test", action: WatchedWord.actions[:block])

      expect_invalid(
        "test",
        error_message: I18n.t(:"user.username.contains_blocked_word", word: "test"),
      )
    end

    it "is valid when username contains watched word but not as complete word" do
      WatchedWord.create!(word: "test", action: WatchedWord.actions[:block])

      expect_valid("testing", "mytest", "protest")
    end

    it "is invalid when username contains watched word from any action type" do
      WatchedWord.create!(word: "*block*", action: WatchedWord.actions[:block])
      WatchedWord.create!(word: "*censor*", action: WatchedWord.actions[:censor])
      WatchedWord.create!(word: "*flag*", action: WatchedWord.actions[:flag])
      WatchedWord.create!(word: "*silence*", action: WatchedWord.actions[:silence])
      WatchedWord.create!(word: "*approve*", action: WatchedWord.actions[:require_approval])

      %w[
        user_with_block
        user_with_censor
        user_with_flag
        user_with_silence
        user_with_approve
      ].each do |username|
        validator = UsernameValidator.new(username)
        expect(validator.valid_format?).to eq(false), "Expected #{username} to be invalid"
        expect(validator.errors.first).to include("blocked word")
      end
    end
  end
end
