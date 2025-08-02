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

    before { Fabricate(:theme, id: 44, remote_theme: remote, name: "Test< Theme") }

    context "when theme is out of date" do
      let(:commits_behind) { 2 }

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          'Updates are available for the following themes:<ul><li><a href="/admin/customize/themes/44">Test&lt; Theme</a></li></ul>',
        )
      end
    end

    context "when theme is up to date" do
      let(:commits_behind) { 0 }

      it { expect(check).to be_chill_about_it }
    end
  end
end
