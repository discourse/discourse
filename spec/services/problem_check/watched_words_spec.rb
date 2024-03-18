# frozen_string_literal: true

RSpec.describe ProblemCheck::WatchedWords do
  subject(:check) { described_class.new }

  context "when all regular expressions are valid" do
    before { WordWatcher.stubs(:compiled_regexps_for_action).returns([]) }

    it { expect(check).to be_chill_about_it }
  end

  context "when regular expressions are invalid" do
    before { WordWatcher.stubs(:compiled_regexps_for_action).raises(RegexpError.new) }

    it do
      expect(check).to have_a_problem.with_priority("low").with_message(
        "The regular expression for 'Block', 'Censor', 'Require Approval', 'Flag', 'Link', 'Replace', 'Tag', 'Silence' watched words is invalid. Please check your <a href='/admin/customize/watched_words'>Watched Word settings</a>, or disable the 'watched words regular expressions' site setting.",
      )
    end
  end
end
