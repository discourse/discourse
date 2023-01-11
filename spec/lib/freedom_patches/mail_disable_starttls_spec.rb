# frozen_string_literal: true

RSpec.describe FreedomPatches::MailDisableStarttls do
  subject(:smtp_session) { smtp.build_smtp_session }

  let(:smtp) { Mail::SMTP.new(options) }

  context "when the starttls option is not provided" do
    let(:options) { {} }

    it "doesn't disable starttls" do
      expect(smtp_session.starttls?).to eq(:auto)
    end
  end

  context "when the starttls option is set to `false`" do
    let(:options) { { enable_starttls_auto: false } }

    it "properly disables starttls" do
      expect(smtp_session.starttls?).to eq(false)
    end
  end
end
