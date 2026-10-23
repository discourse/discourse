# frozen_string_literal: true

RSpec.describe DsaNotification do
  describe ".template_key" do
    let(:template) { "system_messages.post_hidden.text_body_template" }
    let(:context) { { "source" => "review" } }

    it "keeps the original template for ordinary messages and community reports" do
      [nil, { "source" => "flag" }].each do |notification_context|
        expect(
          described_class.template_key(template, context: notification_context, locale: "en"),
        ).to eq(template)
      end
    end

    it "selects the own moderation template for site review" do
      expect(described_class.template_key(template, context:, locale: "en")).to eq(
        "dsa_notifications.post_hidden.text_body_template",
      )
    end

    it "keeps other notification templates" do
      other_template = "system_messages.silenced_by_staff.text_body_template"

      expect(described_class.template_key(other_template, context:, locale: "en")).to eq(
        other_template,
      )
    end

    it "preserves each customized message part independently in its locale" do
      TranslationOverride.upsert!("en", template, "Our custom message")
      subject_template = "system_messages.post_hidden.subject_template"

      expect(described_class.template_key(template, context:, locale: "en")).to eq(template)
      expect(described_class.template_key(subject_template, context:, locale: "en")).to eq(
        "dsa_notifications.post_hidden.subject_template",
      )
      expect(described_class.template_key(template, context:, locale: "fr")).to eq(
        "dsa_notifications.post_hidden.text_body_template",
      )
    end
  end
end
