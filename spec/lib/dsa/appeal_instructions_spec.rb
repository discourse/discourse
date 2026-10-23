# frozen_string_literal: true

RSpec.describe Dsa::AppealInstructions do
  describe ".message_options" do
    before do
      SiteSetting.dsa_moderation_appeal_email = ""
      SiteSetting.contact_email = ""
    end

    context "when the dsa_reporting_enabled site setting is enabled" do
      before { SiteSetting.dsa_reporting_enabled = true }

      it "uses the DSA appeal address" do
        SiteSetting.dsa_moderation_appeal_email = "appeals@example.com"
        SiteSetting.contact_email = "contact@example.com"

        expect(described_class.message_options).to eq(
          body_suffix_key: "system_messages.moderation_appeal_instructions",
          email: "appeals@example.com",
        )
      end

      it "omits instructions when only the site contact email is configured" do
        SiteSetting.contact_email = "contact@example.com"

        expect(described_class.message_options).to eq({})
      end

      it "returns no paragraph when the DSA appeal address is blank" do
        expect(described_class.message_options).to eq({})
      end
    end

    context "when the dsa_reporting_enabled site setting is disabled" do
      before { SiteSetting.dsa_reporting_enabled = false }

      it "returns no paragraph when DSA reporting is disabled" do
        SiteSetting.dsa_moderation_appeal_email = "appeals@example.com"
        SiteSetting.contact_email = "contact@example.com"

        expect(described_class.message_options).to eq({})
      end
    end
  end
end
