# frozen_string_literal: true

describe "ZapierWebhook" do
  fab!(:topic)

  fab!(:automation) { Fabricate(:automation, script: DiscourseAutomation::Scripts::ZAPIER_WEBHOOK) }

  context "with valid webhook url" do
    before do
      automation.upsert_field!(
        "webhook_url",
        "text",
        { value: "https://hooks.zapier.com/hooks/catch/foo/bar" },
      )
    end

    it "enqueues the zapier call" do
      expect { automation.trigger! }.to change {
        Jobs::DiscourseAutomation::CallZapierWebhook.jobs.length
      }.by(1)
    end
  end

  context "with invalid webhook url" do
    before do
      @orig_logger = Rails.logger
      Rails.logger = @fake_logger = FakeLogger.new
    end

    after { Rails.logger = @orig_logger }

    it "logs an error and do nothing" do
      expect { automation.trigger! }.not_to change {
        Jobs::DiscourseAutomation::CallZapierWebhook.jobs.length
      }

      expect(Rails.logger.warnings.first).to match(/is not a valid Zapier/)
    end
  end
end
