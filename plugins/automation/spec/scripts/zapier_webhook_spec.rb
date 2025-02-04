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
    let(:fake_logger) { FakeLogger.new }

    before { Rails.logger.broadcast_to(fake_logger) }

    after { Rails.logger.stop_broadcasting_to(fake_logger) }

    it "logs an error and do nothing" do
      expect { automation.trigger! }.not_to change {
        Jobs::DiscourseAutomation::CallZapierWebhook.jobs.length
      }

      expect(Rails.logger.warnings.first).to match(/is not a valid Zapier/)
    end
  end
end
