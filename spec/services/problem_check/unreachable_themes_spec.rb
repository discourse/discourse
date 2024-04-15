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

    before { Fabricate(:theme, id: 50, remote_theme: remote, name: "Test Theme") }

    context "when theme is unreachable" do
      let(:last_error) { "Can't reach. Too short." }

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          'We were unable to check for updates on the following themes:<ul><li><a href="/admin/customize/themes/50">Test Theme</a></li></ul>',
        )
      end
    end

    context "when theme is reachable" do
      let(:last_error) { nil }

      it { expect(check).to be_chill_about_it }
    end
  end
end
