# frozen_string_literal: true

RSpec.describe ProblemCheck::WatchedWords do
  subject(:check) { described_class.new }

  context "when all regular expressions are valid" do
    before { WordWatcher.stubs(:compiled_regexps_for_action).returns([]) }

    it { expect(check.call).to be_empty }
  end

  context "when regular expressions are invalid" do
    before { WordWatcher.stubs(:compiled_regexps_for_action).raises(RegexpError.new) }

    it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
  end
end
