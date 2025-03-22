# frozen_string_literal: true

RSpec.describe ProblemCheck::FullPageLoginCheck do
  let(:check) { described_class.new }

  describe "#call" do
    context "when full_page_login is enabled" do
      before { SiteSetting.full_page_login = true }

      it { expect(check).to be_chill_about_it }
    end

    context "when full_page_login is enabled" do
      before { SiteSetting.full_page_login = false }

      it { expect(check).to have_a_problem.with_priority("low") }
    end
  end
end
