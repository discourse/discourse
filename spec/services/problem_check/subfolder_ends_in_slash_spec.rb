# frozen_string_literal: true

RSpec.describe ProblemCheck::SubfolderEndsInSlash do
  subject(:check) { described_class.new }

  describe ".call" do
    before { Discourse.stubs(base_path: path) }

    context "when path doesn't end in a slash" do
      let(:path) { "cats" }

      it { expect(check).to be_chill_about_it }
    end

    context "when path ends in a slash" do
      let(:path) { "cats/" }

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          "Your subfolder setup is incorrect; the DISCOURSE_RELATIVE_URL_ROOT ends in a slash.",
        )
      end
    end
  end
end
