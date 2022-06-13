# frozen_string_literal: true

describe FreedomPatches::MailDisableStarttls do
  subject(:smtp_session) { smtp.build_smtp_session }

  let(:smtp) { Mail::SMTP.new(options) }

  context "when the starttls option is not provided" do
    let(:options) { {} }

    it "doesn't disable starttls" do
      expect(smtp_session).to be_starttls
    end
  end

  context "when the starttls option is set to `false`" do
    let(:options) { { enable_starttls_auto: false } }

    it "properly disables starttls" do
      expect(smtp_session).not_to be_starttls
    end
  end
end
