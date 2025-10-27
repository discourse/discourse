# frozen_string_literal: true

RSpec.describe ProblemCheck::StarttlsDisabled do
  subject(:check) { described_class.new }

  describe ".call" do
    context "with STARTTLS enabled" do
      before { GlobalSetting.stubs(:smtp_enable_start_tls).returns(true) }
      it { expect(check).to be_chill_about_it }
    end

    context "with STARTTLS disabled" do
      before { GlobalSetting.stubs(:smtp_enable_start_tls).returns(false) }
      it do
        expect(check).to have_a_problem.with_priority("high").with_message(
          I18n.t("dashboard.problem.#{check.identifier}"),
        )
      end
    end
  end
end
