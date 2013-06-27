require 'spec_helper'
require 'text_cleaner'

describe TextCleaner do

  context "exclamation marks" do

    let(:duplicated_string) { "my precious!!!!" }
    let(:deduplicated_string) { "my precious!" }

    it "ignores multiple ! by default" do
      TextCleaner.clean(duplicated_string).should == duplicated_string
    end

    it "deduplicates ! when enabled" do
      TextCleaner.clean(duplicated_string, deduplicate_exclamation_marks: true).should == deduplicated_string
    end

  end

  context "question marks" do

    let(:duplicated_string) { "please help me????" }
    let(:deduplicated_string) { "please help me?" }

    it "ignores multiple ? by default" do
      TextCleaner.clean(duplicated_string).should == duplicated_string
    end

    it "deduplicates ? when enabled" do
      TextCleaner.clean(duplicated_string, deduplicate_question_marks: true).should == deduplicated_string
    end

  end

  context "all upper case text" do

    let(:all_caps) { "ENTIRE TEXT IS ALL CAPS" }
    let(:almost_all_caps) { "ENTIRE TEXT iS ALL CAPS" }
    let(:regular_case) { "entire text is all caps" }

    it "ignores all upper case text by default" do
      TextCleaner.clean(all_caps).should == all_caps
    end

    it "replaces all upper case text with regular case letters when enabled" do
      TextCleaner.clean(all_caps, replace_all_upper_case: true).should == regular_case
    end

    it "ignores almost all upper case text when enabled" do
      TextCleaner.clean(almost_all_caps, replace_all_upper_case: true).should == almost_all_caps
    end

  end

  context "first letter" do

    let(:lowercased) { "this is awesome" }
    let(:capitalized) { "This is awesome" }
    let(:iletter) { "iLetter" }

    it "ignores first letter case by default" do
      TextCleaner.clean(lowercased).should == lowercased
      TextCleaner.clean(capitalized).should == capitalized
      TextCleaner.clean(iletter).should == iletter
    end

    it "capitalizes first letter when enabled" do
      TextCleaner.clean(lowercased, capitalize_first_letter: true).should == capitalized
      TextCleaner.clean(capitalized, capitalize_first_letter: true).should == capitalized
      TextCleaner.clean(iletter, capitalize_first_letter: true).should == iletter
    end

  end

  context "periods at the end" do

    let(:with_one_period) { "oops." }
    let(:with_several_periods) { "oops..." }
    let(:without_period) { "oops" }

    it "ignores unnecessary periods at the end by default" do
      TextCleaner.clean(with_one_period).should == with_one_period
      TextCleaner.clean(with_several_periods).should == with_several_periods
    end

    it "removes unnecessary periods at the end when enabled" do
      TextCleaner.clean(with_one_period, remove_all_periods_from_the_end: true).should == without_period
      TextCleaner.clean(with_several_periods, remove_all_periods_from_the_end: true).should == without_period
    end

    it "keeps trailing whitespaces when enabled" do
      TextCleaner.clean(with_several_periods + " ", remove_all_periods_from_the_end: true).should == without_period + " "
    end

  end

  context "extraneous space" do

    let(:with_space_exclamation) { "oops !" }
    let(:without_space_exclamation) { "oops!" }
    let(:with_space_question) { "oops ?" }
    let(:without_space_question) { "oops?" }

    it "ignores extraneous space before the end punctuation by default" do
      TextCleaner.clean(with_space_exclamation).should == with_space_exclamation
      TextCleaner.clean(with_space_question).should == with_space_question
    end

    it "removes extraneous space before the end punctuation when enabled" do
      TextCleaner.clean(with_space_exclamation, remove_extraneous_space: true).should == without_space_exclamation
      TextCleaner.clean(with_space_question, remove_extraneous_space: true).should == without_space_question
    end

    it "keep trailing whitespaces when enabled" do
      TextCleaner.clean(with_space_exclamation + " ", remove_extraneous_space: true).should == without_space_exclamation + " "
      TextCleaner.clean(with_space_question + " ", remove_extraneous_space: true).should == without_space_question + " "
    end

  end

  context "interior spaces" do

    let(:spacey_string) { "hello     there's weird     spaces here." }
    let(:unspacey_string) { "hello there's weird spaces here." }

    it "ignores interior spaces by default" do
      TextCleaner.clean(spacey_string).should == spacey_string
    end

    it "fixes interior spaces when enabled" do
      TextCleaner.clean(spacey_string, fixes_interior_spaces: true).should == unspacey_string
    end

  end

  context "leading and trailing whitespaces" do

    let(:spacey_string) { "   \t  test \n  " }
    let(:unspacey_string) { "test" }

    it "ignores leading and trailing whitespaces by default" do
      TextCleaner.clean(spacey_string).should == spacey_string
    end

    it "strips leading and trailing whitespaces when enabled" do
      TextCleaner.clean(spacey_string, strip_whitespaces: true).should == unspacey_string
    end

  end

  context "title" do

    it "fixes interior spaces" do
      TextCleaner.clean_title("Hello   there").should == "Hello there"
    end

    it "strips leading and trailing whitespaces" do
      TextCleaner.clean_title(" \t Hello there \n ").should == "Hello there"
    end

    context "title_prettify site setting is enabled" do

      before { SiteSetting.title_prettify = true }

      it "deduplicates !" do
        TextCleaner.clean_title("Hello there!!!!").should == "Hello there!"
      end

      it "deduplicates ?" do
        TextCleaner.clean_title("Hello there????").should == "Hello there?"
      end

      it "replaces all upper case text with regular case letters" do
        TextCleaner.clean_title("HELLO THERE").should == "Hello there"
      end

      it "capitalizes first letter" do
        TextCleaner.clean_title("hello there").should == "Hello there"
      end

      it "removes unnecessary period at the end" do
        TextCleaner.clean_title("Hello there.").should == "Hello there"
      end

      it "removes extraneous space before the end punctuation" do
        TextCleaner.clean_title("Hello there ?").should == "Hello there?"
      end

    end

  end

end
