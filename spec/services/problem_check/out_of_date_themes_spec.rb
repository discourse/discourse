# frozen_string_literal: true

RSpec.describe ProblemCheck::OutOfDateThemes do
  subject(:check) { described_class.new }

  describe ".call" do
    let(:remote) do
      RemoteTheme.create!(
        remote_url: "https://github.com/org/testtheme",
        commits_behind: commits_behind,
      )
    end

    before { Fabricate(:theme, remote_theme: remote, name: "Test< Theme") }

    context "when theme is out of date" do
      let(:commits_behind) { 2 }

      it { expect(check.call).to include(be_a(ProblemCheck::Problem)) }
    end

    context "when theme is up to date" do
      let(:commits_behind) { 0 }

      it { expect(check.call).to be_empty }
    end
  end
end
