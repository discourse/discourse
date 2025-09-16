# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiUsageController do
  fab!(:admin)
  fab!(:user)
  fab!(:llm_model)
  let(:usage_report_path) { "/admin/plugins/discourse-ai/ai-usage-report.json" }

  before { enable_current_plugin }

  context "when logged in as admin" do
    before { sign_in(admin) }

    describe "#show" do
      fab!(:log1) do
        AiApiAuditLog.create!(
          provider_id: 1,
          feature_name: "summarize",
          language_model: "gpt-4",
          request_tokens: 100,
          response_tokens: 50,
          created_at: 1.day.ago,
        )
      end

      fab!(:log2) do
        AiApiAuditLog.create!(
          provider_id: 1,
          feature_name: "translate",
          language_model: "gpt-3.5",
          request_tokens: 200,
          response_tokens: 100,
          created_at: 2.days.ago,
        )
      end

      fab!(:log3) do
        AiApiAuditLog.create!(
          provider_id: 1,
          feature_name: "ai_helper",
          language_model: llm_model.name,
          request_tokens: 300,
          response_tokens: 150,
          cached_tokens: 50,
          created_at: 3.days.ago,
        )
      end

      it "returns correct data structure" do
        get usage_report_path

        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json).to have_key("data")
        expect(json).to have_key("features")
        expect(json).to have_key("models")
        expect(json).to have_key("summary")
      end

      it "respects date filters" do
        get usage_report_path,
            params: {
              start_date: 3.days.ago.to_date,
              end_date: 1.day.ago.to_date,
            }

        json = response.parsed_body
        expect(json["summary"]["total_tokens"]).to eq(900) # sum of all tokens
      end

      it "filters by feature" do
        get usage_report_path, params: { feature: "summarize" }

        json = response.parsed_body

        features = json["features"]
        expect(features.length).to eq(1)
        expect(features.first["feature_name"]).to eq("summarize")
        expect(features.first["total_tokens"]).to eq(150)
      end

      it "filters by model" do
        get usage_report_path, params: { model: "gpt-3.5" }

        json = response.parsed_body
        models = json["models"]
        expect(models.length).to eq(1)
        expect(models.first["llm"]).to eq("gpt-3.5")
        expect(models.first["total_tokens"]).to eq(300)
      end

      it "shows an estimated cost" do
        get usage_report_path, params: { model: llm_model.name }

        json = response.parsed_body
        summary = json["summary"]
        feature = json["features"].find { |f| f["feature_name"] == "ai_helper" }

        expected_input_spending = llm_model.input_cost * log3.request_tokens / 1_000_000.0
        expected_cached_input_spending =
          llm_model.cached_input_cost * log3.cached_tokens / 1_000_000.0
        expected_output_spending = llm_model.output_cost * log3.response_tokens / 1_000_000.0
        expected_total_spending =
          expected_input_spending + expected_cached_input_spending + expected_output_spending

        expect(feature["input_spending"].to_s).to eq(expected_input_spending.to_s)
        expect(feature["output_spending"].to_s).to eq(expected_output_spending.to_s)
        expect(feature["cached_input_spending"].to_s).to eq(expected_cached_input_spending.to_s)
        expect(summary["total_spending"].to_s).to eq(expected_total_spending.round(2).to_s)
      end

      it "handles different period groupings" do
        get usage_report_path, params: { period: "hour" }
        expect(response.status).to eq(200)

        get usage_report_path, params: { period: "month" }
        expect(response.status).to eq(200)
      end
    end

    # spec/requests/admin/ai_usage_controller_spec.rb
    context "with hourly data" do
      before do
        freeze_time Time.parse("2021-02-01 00:00:00")
        # Create data points across different hours
        [23.hours.ago, 22.hours.ago, 21.hours.ago, 20.hours.ago].each do |time|
          AiApiAuditLog.create!(
            provider_id: 1,
            feature_name: "summarize",
            language_model: "gpt-4",
            request_tokens: 100,
            response_tokens: 50,
            created_at: time,
          )
        end
      end

      it "returns hourly data when period is day" do
        get usage_report_path,
            params: {
              start_date: 1.day.ago.to_date,
              end_date: Time.current.to_date,
            }

        expect(response.status).to eq(200)
        json = response.parsed_body

        expect(json["data"].length).to eq(4)

        data_by_hour = json["data"].index_by { |d| Time.parse(d["period"]).hour }

        expect(data_by_hour.keys.length).to eq(4)
        expect(data_by_hour.first[1]["total_tokens"]).to eq(150)
      end
    end

    context "with different timezones" do
      before { freeze_time Time.parse("2024-07-28 00:30:00 UTC") }

      let(:base_time) { Time.parse("2024-07-28 00:30:00 UTC") } # 8:30 AM Singapore
      let(:singapore_tz) { "Asia/Singapore" }

      let!(:log_sg1) do
        AiApiAuditLog.create!(
          provider_id: 1,
          feature_name: "summarize",
          language_model: "gpt-4",
          request_tokens: 1000,
          response_tokens: 50,
          created_at: base_time,
        )
      end

      let!(:log_sg2) do
        AiApiAuditLog.create!(
          provider_id: 1,
          feature_name: "summarize",
          language_model: "gpt-4",
          request_tokens: 1000,
          response_tokens: 50,
          created_at: base_time - 1.hour,
        )
      end

      it "shows correct data across timezone boundaries" do
        report =
          DiscourseAi::Completions::Report.new(
            start_date: base_time.in_time_zone(singapore_tz).beginning_of_day,
            end_date: base_time.in_time_zone(singapore_tz).end_of_day,
            timezone: singapore_tz,
          )

        expect(report.tokens_by_period(:hour).count).to eq(2)
      end
    end
  end

  context "when not admin" do
    before { sign_in(user) }

    it "blocks access" do
      get usage_report_path
      expect(response.status).to eq(404)
    end
  end

  context "when plugin disabled" do
    before do
      SiteSetting.discourse_ai_enabled = false
      sign_in(admin)
    end

    it "returns error" do
      get usage_report_path
      expect(response.status).to eq(404)
    end
  end
end
