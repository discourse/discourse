require 'rails_helper'
require 'text_cleaner'

describe TextCleaner do

  context "exclamation marks" do

    let(:duplicated_string) { "my precious!!!!" }
    let(:deduplicated_string) { "my precious!" }

    it "ignores multiple ! by default" do
      expect(TextCleaner.clean(duplicated_string)).to eq(duplicated_string)
    end

    it "deduplicates ! when enabled" do
      expect(TextCleaner.clean(duplicated_string, deduplicate_exclamation_marks: true)).to eq(deduplicated_string)
    end

  end

  context "question marks" do

    let(:duplicated_string) { "please help me????" }
    let(:deduplicated_string) { "please help me?" }

    it "ignores multiple ? by default" do
      expect(TextCleaner.clean(duplicated_string)).to eq(duplicated_string)
    end

    it "deduplicates ? when enabled" do
      expect(TextCleaner.clean(duplicated_string, deduplicate_question_marks: true)).to eq(deduplicated_string)
    end

  end

  context "all upper case text" do

    let(:all_caps) { "ENTIRE TEXT IS ALL CAPS" }
    let(:almost_all_caps) { "ENTIRE TEXT iS ALL CAPS" }
    let(:regular_case) { "entire text is all caps" }

    it "ignores all upper case text by default" do
      expect(TextCleaner.clean(all_caps)).to eq(all_caps)
    end

    it "replaces all upper case text with regular case letters when enabled" do
      expect(TextCleaner.clean(all_caps, replace_all_upper_case: true)).to eq(regular_case)
    end

    it "ignores almost all upper case text when enabled" do
      expect(TextCleaner.clean(almost_all_caps, replace_all_upper_case: true)).to eq(almost_all_caps)
    end

  end

  context "first letter" do

    let(:lowercased) { "this is awesome" }
    let(:capitalized) { "This is awesome" }
    let(:iletter) { "iLetter" }

    it "ignores first letter case by default" do
      expect(TextCleaner.clean(lowercased)).to eq(lowercased)
      expect(TextCleaner.clean(capitalized)).to eq(capitalized)
      expect(TextCleaner.clean(iletter)).to eq(iletter)
    end

    it "capitalizes first letter when enabled" do
      expect(TextCleaner.clean(lowercased, capitalize_first_letter: true)).to eq(capitalized)
      expect(TextCleaner.clean(capitalized, capitalize_first_letter: true)).to eq(capitalized)
      expect(TextCleaner.clean(iletter, capitalize_first_letter: true)).to eq(iletter)
    end

  end

  context "periods at the end" do

    let(:with_one_period) { "oops." }
    let(:with_several_periods) { "oops..." }
    let(:without_period) { "oops" }

    it "ignores unnecessary periods at the end by default" do
      expect(TextCleaner.clean(with_one_period)).to eq(with_one_period)
      expect(TextCleaner.clean(with_several_periods)).to eq(with_several_periods)
    end

    it "removes unnecessary periods at the end when enabled" do
      expect(TextCleaner.clean(with_one_period, remove_all_periods_from_the_end: true)).to eq(without_period)
      expect(TextCleaner.clean(with_several_periods, remove_all_periods_from_the_end: true)).to eq(without_period)
    end

    it "keeps trailing whitespaces when enabled" do
      expect(TextCleaner.clean(with_several_periods + " ", remove_all_periods_from_the_end: true)).to eq(without_period + " ")
    end

  end

  context "extraneous space" do

    let(:with_space_exclamation) { "oops !" }
    let(:without_space_exclamation) { "oops!" }
    let(:with_space_question) { "oops ?" }
    let(:without_space_question) { "oops?" }

    it "ignores extraneous space before the end punctuation by default" do
      expect(TextCleaner.clean(with_space_exclamation)).to eq(with_space_exclamation)
      expect(TextCleaner.clean(with_space_question)).to eq(with_space_question)
    end

    it "removes extraneous space before the end punctuation when enabled" do
      expect(TextCleaner.clean(with_space_exclamation, remove_extraneous_space: true)).to eq(without_space_exclamation)
      expect(TextCleaner.clean(with_space_question, remove_extraneous_space: true)).to eq(without_space_question)
    end

    it "keep trailing whitespaces when enabled" do
      expect(TextCleaner.clean(with_space_exclamation + " ", remove_extraneous_space: true)).to eq(without_space_exclamation + " ")
      expect(TextCleaner.clean(with_space_question + " ", remove_extraneous_space: true)).to eq(without_space_question + " ")
    end

  end

  context "interior spaces" do

    let(:spacey_string) { "hello     there's weird     spaces here." }
    let(:unspacey_string) { "hello there's weird spaces here." }

    it "ignores interior spaces by default" do
      expect(TextCleaner.clean(spacey_string)).to eq(spacey_string)
    end

    it "fixes interior spaces when enabled" do
      expect(TextCleaner.clean(spacey_string, fixes_interior_spaces: true)).to eq(unspacey_string)
    end

  end

  context "leading and trailing whitespaces" do

    let(:spacey_string) { "   \t  test \n  " }
    let(:unspacey_string) { "test" }

    it "ignores leading and trailing whitespaces by default" do
      expect(TextCleaner.clean(spacey_string)).to eq(spacey_string)
    end

    it "strips leading and trailing whitespaces when enabled" do
      expect(TextCleaner.clean(spacey_string, strip_whitespaces: true)).to eq(unspacey_string)
    end

  end

  context "title" do

    it "fixes interior spaces" do
      expect(TextCleaner.clean_title("Hello   there")).to eq("Hello there")
    end

    it "strips leading and trailing whitespaces" do
      expect(TextCleaner.clean_title(" \t Hello there \n ")).to eq("Hello there")
    end

    it "strips zero width spaces" do
      expect(TextCleaner.clean_title("Hello​ ​there")).to eq("Hello there")
      expect(TextCleaner.clean_title("Hello​ ​there").length).to eq(11)
    end

    context "title_prettify site setting is enabled" do

      before { SiteSetting.title_prettify = true }

      it "deduplicates !" do
        expect(TextCleaner.clean_title("Hello there!!!!")).to eq("Hello there!")
      end

      it "deduplicates ?" do
        expect(TextCleaner.clean_title("Hello there????")).to eq("Hello there?")
      end

      it "replaces all upper case text with regular case letters" do
        expect(TextCleaner.clean_title("HELLO THERE")).to eq("Hello there")
      end

      it "doesn't replace all upper case text when uppercase posts are allowed" do
        SiteSetting.allow_uppercase_posts = true
        expect(TextCleaner.clean_title("HELLO THERE")).to eq("HELLO THERE")
      end

      it "capitalizes first letter" do
        expect(TextCleaner.clean_title("hello there")).to eq("Hello there")
      end

      it "removes unnecessary period at the end" do
        expect(TextCleaner.clean_title("Hello there.")).to eq("Hello there")
      end

      it "removes extraneous space before the end punctuation" do
        expect(TextCleaner.clean_title("Hello there ?")).to eq("Hello there?")
      end

      it "replaces all upper case unicode text with regular unicode case letters" do
        expect(TextCleaner.clean_title("INVESTIGAÇÃO POLÍTICA NA CÂMARA")).to eq("Investigação política na câmara")
      end

      it "doesn't downcase text if only one word is upcase in a non-ascii alphabet" do
        expect(TextCleaner.clean_title("«Эта неделя в EVE»")).to eq("«Эта неделя в EVE»")
      end

      it "capitalizes first unicode letter" do
        expect(TextCleaner.clean_title("épico encontro")).to eq("Épico encontro")
      end

    end

  end

  describe "#normalize_whitespaces" do
    it "normalize whitespaces" do
      whitespaces = "\u0020\u00A0\u1680\u180E\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u2028\u2029\u202F\u205F\u3000"
      expect(whitespaces.strip).not_to eq("")
      expect(TextCleaner.normalize_whitespaces(whitespaces).strip).to eq("")
      expect(TextCleaner.normalize_whitespaces(nil)).to be_nil
    end

    it "does not muck with zero width white space" do
      # this is used for khmer, dont mess with it
      expect(TextCleaner.normalize_whitespaces("hello\u200Bworld").strip).to eq("hello\u200Bworld")
      expect(TextCleaner.normalize_whitespaces("hello\uFEFFworld").strip).to eq("hello\uFEFFworld")

    end
  end

end
