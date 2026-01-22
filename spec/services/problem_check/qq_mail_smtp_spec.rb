# frozen_string_literal: true

RSpec.describe ProblemCheck::QqMailSmtp do
  subject(:check) { described_class.new }

  describe ".call" do
    before { ActionMailer::Base.stubs(smtp_settings: { address: smtp_address }) }

    context "when not using QQ Mail" do
      let(:smtp_address) { "smtp.mailgun.org" }

      it { expect(check).to be_chill_about_it }
    end

    context "when using QQ Mail" do
      let(:smtp_address) { "smtp.qq.com" }

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          "Your SMTP server (smtp.qq.com) is known to cause duplicate emails with Discourse. QQ Mail does not return proper acknowledgments, causing Discourse to retry sends that already succeeded. <a href='https://github.com/discourse/discourse/blob/main/docs/INSTALL-email.md' target='_blank'>See recommended alternatives</a>.",
        )
      end
    end

    context "when using QQ Enterprise Mail (Exmail)" do
      let(:smtp_address) { "smtp.exmail.qq.com" }

      it do
        expect(check).to have_a_problem.with_priority("low").with_message(
          "Your SMTP server (smtp.exmail.qq.com) is known to cause duplicate emails with Discourse. QQ Mail does not return proper acknowledgments, causing Discourse to retry sends that already succeeded. <a href='https://github.com/discourse/discourse/blob/main/docs/INSTALL-email.md' target='_blank'>See recommended alternatives</a>.",
        )
      end
    end

    context "when SMTP address is nil" do
      let(:smtp_address) { nil }

      it { expect(check).to be_chill_about_it }
    end

    context "when SMTP address is a suffix false positive" do
      let(:smtp_address) { "notqq.com" }

      it { expect(check).to be_chill_about_it }
    end
  end
end
