# frozen_string_literal: true

require 'rails_helper'

describe UsernameValidator do
  def expect_valid(*usernames)
    usernames.each do |username|
      validator = UsernameValidator.new(username)

      aggregate_failures do
        expect(validator.valid_format?).to eq(true), "expected '#{username}' to be valid"
        expect(validator.errors).to be_empty
      end
    end
  end

  def expect_invalid(*usernames, error_message:)
    usernames.each do |username|
      validator = UsernameValidator.new(username)

      aggregate_failures do
        expect(validator.valid_format?).to eq(false), "expected '#{username}' to be invalid"
        expect(validator.errors).to include(error_message)
      end
    end
  end

  shared_examples 'ASCII username' do
    it 'is invalid when the username is blank' do
      expect_invalid('', error_message: I18n.t(:'user.username.blank'))
    end

    it 'is invalid when the username is too short' do
      SiteSetting.min_username_length = 4

      expect_invalid('a', 'ab', 'abc',
                     error_message: I18n.t(:'user.username.short', min: 4))
    end

    it 'is valid when the username has the minimum lenght' do
      SiteSetting.min_username_length = 4

      expect_valid('abcd')
    end

    it 'is invalid when the username is too long' do
      SiteSetting.max_username_length = 8

      expect_invalid('abcdefghi',
                     error_message: I18n.t(:'user.username.long', max: 8))
    end

    it 'is valid when the username has the maximum lenght' do
      SiteSetting.max_username_length = 8

      expect_valid('abcdefgh')
    end

    it 'is valid when the username contains alphanumeric characters, dots, underscores and dashes' do
      expect_valid('ab-cd.123_ABC-xYz')
    end

    it 'is invalid when the username contains non-alphanumeric characters other than dots, underscores and dashes' do
      expect_invalid('abc|', 'a#bc', 'abc xyz',
                     error_message: I18n.t(:'user.username.characters'))
    end

    it 'is valid when the username starts with a alphanumeric character or underscore' do
      expect_valid('abcd', '1abc', '_abc')
    end

    it 'is invalid when the username starts with a dot or dash' do
      expect_invalid('.abc', '-abc',
                     error_message: I18n.t(:'user.username.must_begin_with_alphanumeric_or_underscore'))
    end

    it 'is valid when the username ends with a alphanumeric character' do
      expect_valid('abcd', 'abc9')
    end

    it 'is invalid when the username ends with an underscore, a dot or dash' do
      expect_invalid('abc_', 'abc.', 'abc-',
                     error_message: I18n.t(:'user.username.must_end_with_alphanumeric'))
    end

    it 'is invalid when the username contains consecutive underscores, dots or dashes' do
      expect_invalid('a__bc', 'a..bc', 'a--bc',
                     error_message: I18n.t(:'user.username.must_not_contain_two_special_chars_in_seq'))
    end

    it 'is invalid when the username ends with certain file extensions' do
      expect_invalid('abc.json', 'abc.png',
                     error_message: I18n.t(:'user.username.must_not_end_with_confusing_suffix'))
    end
  end

  context 'when Unicode usernames are disabled' do
    before { SiteSetting.unicode_usernames = false }

    include_examples 'ASCII username'

    it 'is invalid when the username contains non-ASCII characters except dots, underscores and dashes' do
      expect_invalid('abcö', 'abc象',
                     error_message: I18n.t(:'user.username.characters'))
    end
  end

  context 'when Unicode usernames are enabled' do
    before { SiteSetting.unicode_usernames = true }

    context "ASCII usernames" do
      include_examples 'ASCII username'
    end

    context "Unicode usernames" do
      before { SiteSetting.min_username_length = 1 }

      it 'is invalid when the username is too short' do
        SiteSetting.min_username_length = 3

        expect_invalid('鳥', 'পাখি',
                       error_message: I18n.t(:'user.username.short', min: 3))
      end

      it 'is valid when the username has the minimum lenght' do
        SiteSetting.min_username_length = 2

        expect_valid('পাখি', 'طائر')
      end

      it 'is invalid when the username is too long' do
        SiteSetting.max_username_length = 8

        expect_invalid('חוטב_עצים', 'Holzfäller',
                       error_message: I18n.t(:'user.username.long', max: 8))
      end

      it 'is valid when the username has the maximum lenght' do
        SiteSetting.max_username_length = 9

        expect_valid('Дровосек', 'چوب-لباسی', 'தமிழ்-தமிழ்')
      end

      it 'is invalid when the username has too many Unicode codepoints' do
        SiteSetting.max_username_length = 30

        expect_invalid('য়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়ায়া',
                       error_message: I18n.t(:'user.username.too_long'))
      end

      it 'is valid when the username contains Unicode letters' do
        expect_valid('鳥', 'طائر', 'թռչուն', 'πουλί', 'পাখি', 'madár', '새',
                     'پرنده', 'птица', 'fågel', 'นก', 'پرندے', 'ציפור')
      end

      it 'is valid when the username contains numbers from the Nd or Nl Unicode category' do
        expect_valid('arabic٠١٢٣٤٥٦٧٨٩', 'bengali০১২৩৪৫৬৭৮৯', 'romanⅥ', 'hangzhou〺')
      end

      it 'is invalid when the username contains numbers from the No Unicode category' do
        expect_invalid('circled㊸', 'fraction¾',
                       error_message: I18n.t(:'user.username.characters'))
      end

      it 'is invalid when the username contains symbols or emojis' do
        SiteSetting.min_username_length = 1

        expect_invalid('©', '⇨', '“', '±', '‿', '😃', '🚗',
                       error_message: I18n.t(:'user.username.characters'))
      end

      it 'is invalid when the username contains zero width join characters' do
        expect_invalid('ണ്‍', 'র‌্যাম',
                       error_message: I18n.t(:'user.username.characters'))
      end

      it 'is valid when the username ends with a Unicode Mark' do
        expect_valid('தமிழ்')
      end

      it 'allows all Unicode letters when the whitelist is empty' do
        expect_valid('鳥')
      end

      context "with Unicode whitelist" do
        before { SiteSetting.unicode_username_character_whitelist = "[äöüÄÖÜß]" }

        it 'is invalid when username contains non-whitelisted letters' do
          expect_invalid('鳥', 'francès', error_message: I18n.t(:'user.username.characters'))
        end

        it 'is valid when username contains only whitelisted letters' do
          expect_valid('Löwe', 'Ötzi')
        end

        it 'is valid when username contains only ASCII letters and numbers regardless of whitelist' do
          expect_valid('a-z_A-Z.0-9')
        end

        it 'is valid after resetting the site setting' do
          SiteSetting.unicode_username_character_whitelist = ""
          expect_valid('鳥')
        end
      end
    end
  end
end
