# frozen_string_literal: true

require 'rails_helper'
require 'user_name_suggester'

describe UserNameSuggester do
  describe '.suggest' do
    before do
      SiteSetting.min_username_length = 3
      SiteSetting.max_username_length = 15
    end

    it "keeps adding numbers to the username" do
      Fabricate(:user, username: 'sam')
      Fabricate(:user, username: 'sAm1')
      Fabricate(:user, username: 'sam2')
      Fabricate(:user, username: 'sam4')

      expect(UserNameSuggester.suggest('saM')).to eq('saM3')
    end

    it "doesn't raise an error on nil username" do
      expect(UserNameSuggester.suggest(nil)).to eq(nil)
    end

    it "doesn't raise an error on integer username" do
      expect(UserNameSuggester.suggest(999)).to eq('999')
    end

    it 'corrects weird characters' do
      expect(UserNameSuggester.suggest("Darth%^Vader")).to eq('Darth_Vader')
    end

    it 'adds 1 to an existing username' do
      user = Fabricate(:user)
      expect(UserNameSuggester.suggest(user.username)).to eq("#{user.username}1")
    end

    it "adds numbers if it's too short" do
      expect(UserNameSuggester.suggest('a')).to eq('a11')
    end

    it 'is able to guess a decent username from an email' do
      expect(UserNameSuggester.suggest('bob@example.com')).to eq('bob')
    end

    it "has a special case for me and i emails" do
      expect(UserNameSuggester.suggest('me@eviltrout.com')).to eq('eviltrout')
      expect(UserNameSuggester.suggest('i@eviltrout.com')).to eq('eviltrout')
    end

    it "shortens very long suggestions" do
      expect(UserNameSuggester.suggest("myreallylongnameisrobinwardesquire")).to eq('myreallylongnam')
    end

    it "makes room for the digit added if the username is too long" do
      User.create(username: 'myreallylongnam', email: 'fake@discourse.org')
      expect(UserNameSuggester.suggest("myreallylongnam")).to eq('myreallylongna1')
    end

    it "doesn't suggest reserved usernames" do
      SiteSetting.reserved_usernames = 'myadmin|steve|steve1'
      expect(UserNameSuggester.suggest("myadmin@hissite.com")).to eq('myadmin1')
      expect(UserNameSuggester.suggest("steve")).to eq('steve2')
    end

    it "doesn't suggest generic usernames" do
      UserNameSuggester::GENERIC_NAMES.each do |name|
        expect(UserNameSuggester.suggest("#{name}@apple.org")).to eq('apple')
      end
    end

    it "removes leading character if it is not alphanumeric" do
      expect(UserNameSuggester.suggest(".myname")).to eq('myname')
    end

    it "allows leading _" do
      expect(UserNameSuggester.suggest("_myname")).to eq('_myname')
    end

    it "removes trailing characters if they are invalid" do
      expect(UserNameSuggester.suggest("myname!^$=")).to eq('myname')
    end

    it "allows dots in the middle" do
      expect(UserNameSuggester.suggest("my.name")).to eq('my.name')
    end

    it "remove leading dots" do
      expect(UserNameSuggester.suggest(".myname")).to eq('myname')
    end

    it "remove trailing dots" do
      expect(UserNameSuggester.suggest("myname.")).to eq('myname')
    end

    it 'handles usernames with a sequence of 2 or more special chars' do
      expect(UserNameSuggester.suggest('Darth__Vader')).to eq('Darth_Vader')
      expect(UserNameSuggester.suggest('Darth_-_Vader')).to eq('Darth_Vader')
    end

    it 'should handle typical facebook usernames' do
      expect(UserNameSuggester.suggest('roger.nelson.3344913')).to eq('roger.nelson.33')
    end

    it 'removes underscore at the end of long usernames that get truncated' do
      expect(UserNameSuggester.suggest('uuuuuuuuuuuuuu_u')).to_not end_with('_')
    end

    it "adds number if it's too short after removing trailing underscore" do
      User.stubs(:username_length).returns(8..8)
      expect(UserNameSuggester.suggest('uuuuuuu_u')).to eq('uuuuuuu1')
    end

    context "with Unicode usernames disabled" do
      before { SiteSetting.unicode_usernames = false }

      it "transliterates some characters" do
        expect(UserNameSuggester.suggest('Jørn')).to eq('Jorn')
      end

      it "replaces Unicode characters" do
        expect(UserNameSuggester.suggest('طائر')).to eq('111')
        expect(UserNameSuggester.suggest('πουλί')).to eq('111')
      end
    end

    context "with Unicode usernames enabled" do
      before { SiteSetting.unicode_usernames = true }

      it "does not transliterate" do
        expect(UserNameSuggester.suggest("Jørn")).to eq('Jørn')
      end

      it "does not replace Unicode characters" do
        expect(UserNameSuggester.suggest('طائر')).to eq('طائر')
        expect(UserNameSuggester.suggest('πουλί')).to eq('πουλί')
      end

      it "shortens usernames by counting grapheme clusters" do
        SiteSetting.max_username_length = 10
        expect(UserNameSuggester.suggest('बहुत-लंबा-उपयोगकर्ता-नाम')).to eq('बहुत-लंबा-उपयो')
      end

      it "adds numbers if it's too short" do
        expect(UserNameSuggester.suggest('鳥')).to eq('鳥11')

        # grapheme cluster consists of 3 code points
        expect(UserNameSuggester.suggest('য়া')).to eq('য়া11')
      end

      it "does not skip ove allowed names" do
        Fabricate(:user, username: 'sam')
        Fabricate(:user, username: 'saM1')
        Fabricate(:user, username: 'sam2')

        expect(UserNameSuggester.suggest('SaM', 'Sam1')).to eq('Sam1')
      end

      it "normalizes usernames" do
        actual = 'Löwe'    # NFD, "Lo\u0308we"
        expected = 'Löwe'  # NFC, "L\u00F6we"

        expect(UserNameSuggester.suggest(actual)).to eq(expected)
      end

      it "does not suggest a username longer than max column size" do
        SiteSetting.max_username_length = 40

        expect(UserNameSuggester.suggest('য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া'))
          .to eq('য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া-য়া')
      end

      it "uses whitelist" do
        SiteSetting.unicode_username_character_whitelist = "[äöüßÄÖÜẞ]"

        expect(UserNameSuggester.suggest('πουλί')).to eq('111')
        expect(UserNameSuggester.suggest('a鳥b')).to eq('a_b')
        expect(UserNameSuggester.suggest('Löwe')).to eq('Löwe')

        SiteSetting.unicode_username_character_whitelist = "[য়া]"
        expect(UserNameSuggester.suggest('aয়াb鳥c')).to eq('aয়াb_c')
      end
    end
  end
end
