# frozen_string_literal: true

RSpec.describe ProblemCheck::MissingAwsSnsTopicArn do
  subject(:check) { described_class.new }

  describe ".call" do
    before { ActionMailer::Base.stubs(smtp_settings: { address: smtp_address }) }

    context "when the allowlist is configured" do
      let(:smtp_address) { "email-smtp.us-east-1.amazonaws.com" }

      before { SiteSetting.aws_sns_topic_arn_allowlist = "arn:aws:sns:us-east-1:123:topic" }

      it { expect(check).to be_chill_about_it }
    end

    context "when SMTP is not Amazon SES" do
      let(:smtp_address) { "smtp.sendgrid.net" }

      before { SiteSetting.aws_sns_topic_arn_allowlist = "" }

      it { expect(check).to be_chill_about_it }
    end

    context "when SMTP is Amazon SES and allowlist is empty" do
      let(:smtp_address) { "email-smtp.us-east-1.amazonaws.com" }

      before { SiteSetting.aws_sns_topic_arn_allowlist = "" }

      it { expect(check).to have_a_problem.with_priority("low") }
    end
  end
end
