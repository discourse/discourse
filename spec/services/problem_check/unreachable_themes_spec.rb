# frozen_string_literal: true

RSpec.describe ProblemCheck::UnreachableThemes do
  subject(:check) { described_class.new }

  describe ".call" do
    let(:remote) do
      RemoteTheme.create!(
        remote_url: "https://github.com/org/testtheme",
        last_error_text: last_error,
      )
    end

    before { Fabricate(:theme, remote_theme: remote, name: "Test< Theme") }

    context "when theme is unreachable" do
      let(:last_error) { "Can't reach. Too short." }

      it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
    end

    context "when theme is reachable" do
      let(:last_error) { nil }

      it { expect(check.call).to be_empty }
    end
  end
end
