# frozen_string_literal: true

RSpec.describe ProblemCheck::AdminSidebarDeprecation do
  subject(:check) { described_class.new }

  describe ".call" do
    before { SiteSetting.stubs(admin_sidebar_enabled_groups: configured) }

    context "when sidebar is enabled for some group" do
      let(:configured) { "1" }

      it { expect(check).to be_chill_about_it }
    end

    context "when sidebar is not enabled for any group" do
      let(:configured) { "" }

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          "The old admin layout is deprecated in favour of the new <a href='https://meta.discourse.org/t/introducing-experimental-admin-sidebar-navigation/289281'>sidebar layout</a> and will be removed in the next release. You can <a href='/admin/config/navigation?filter=admin%20sidebar'>configure</a> the new sidebar layout now to opt in before that.",
        )
      end
    end
  end
end
