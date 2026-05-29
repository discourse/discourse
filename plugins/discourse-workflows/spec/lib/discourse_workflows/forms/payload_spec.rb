# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Forms::Payload do
  describe ".build" do
    it "builds form submission data with metadata" do
      freeze_time Time.utc(2026, 1, 1)

      payload = described_class.build({ name: "Joffrey" }, query_parameters: { source: "email" })

      expect(payload).to eq(
        "name" => "Joffrey",
        "submitted_at" => "2026-01-01T00:00:00.000Z",
        "form_mode" => "production",
        "form_query_parameters" => {
          "source" => "email",
        },
      )
    end

    it "falls back to production mode when form mode is blank" do
      payload = described_class.build({}, submitted_at: "now", form_mode: "")

      expect(payload["form_mode"]).to eq("production")
    end
  end

  describe ".form_mode_from" do
    it "reads form mode from trigger data with a production fallback" do
      expect(described_class.form_mode_from("form_mode" => "test")).to eq("test")
      expect(described_class.form_mode_from({})).to eq("production")
    end
  end

  describe ".query_parameters_from" do
    it "reads query parameters from trigger data with an empty fallback" do
      expect(
        described_class.query_parameters_from("form_query_parameters" => { "source" => "email" }),
      ).to eq("source" => "email")
      expect(described_class.query_parameters_from({})).to eq({})
    end
  end
end
