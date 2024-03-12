# frozen_string_literal: true

RSpec.describe ProblemCheck::SubfolderEndsInSlash do
  subject(:check) { described_class.new }

  describe ".call" do
    before { Discourse.stubs(base_path: path) }

    context "when path doesn't end in a slash" do
      let(:path) { "cats" }

      it { expect(check.call).to be_empty }
    end

    context "when path ends in a slash" do
      let(:path) { "cats/" }

      it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
    end
  end
end
