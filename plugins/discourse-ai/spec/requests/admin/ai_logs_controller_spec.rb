# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiLogsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:llm_model)

  let(:index_path) { "/admin/plugins/discourse-ai/ai-logs.json" }

  before do |example|
    enable_current_plugin
    sign_in(admin) if !example.metadata[:anonymous]
  end

  def request_ai_logs_endpoint(endpoint, log, headers: {})
    case endpoint
    when :index
      get index_path, headers:
    when :show
      get "/admin/plugins/discourse-ai/ai-logs/#{log.id}.json", headers:
    when :retention
      put "/admin/plugins/discourse-ai/ai-logs/retention.json",
          params: {
            detailed_days: 30,
            summary_days: 180,
          },
          headers:
    end
  end

  it "defines a display name for every audit provider" do
    AiApiAuditLog::Provider.constants.each do |constant|
      provider_id = AiApiAuditLog::Provider.const_get(constant)
      expect(DiscourseAi::Admin::AiLogSerializerHelpers.provider_name(provider_id)).to be_present
    end
  end

  describe "administrator-only access" do
    fab!(:post)
    fab!(:log) do
      Fabricate(
        :ai_api_audit_log,
        topic: post.topic,
        post:,
        raw_request_payload: "sensitive request",
        raw_response_payload: "sensitive response",
      )
    end

    it "denies anonymous users from every endpoint", :anonymous do
      %i[index show retention].each do |endpoint|
        request_ai_logs_endpoint(endpoint, log)
        expect(response.status).to eq(404),
        "expected #{endpoint} to be hidden from anonymous users, got #{response.status}"
        expect(response.body).not_to include("sensitive request", "sensitive response")
      end
    end

    it "denies regular users and moderators from every endpoint even when they can see the topic" do
      [user, moderator].each do |non_admin|
        sign_in(non_admin)

        %i[index show retention].each do |endpoint|
          request_ai_logs_endpoint(endpoint, log)
          expect(response.status).to eq(404),
          "expected #{endpoint} to be hidden from #{non_admin.username}"
        end
      end
    end

    it "denies non-admin API keys from every endpoint", :anonymous do
      api_key = Fabricate(:api_key, user:)
      headers = { "Api-Key" => api_key.key, "Api-Username" => user.username }

      %i[index show retention].each do |endpoint|
        request_ai_logs_endpoint(endpoint, log, headers:)
        expect(response.status).to eq(404),
        "expected #{endpoint} to be hidden from a non-admin API key"
      end
    end

    it "keeps every endpoint unavailable when the plugin is disabled" do
      SiteSetting.discourse_ai_enabled = false

      %i[index show retention].each do |endpoint|
        request_ai_logs_endpoint(endpoint, log)
        expect(response.status).to eq(404), "expected #{endpoint} to require the enabled plugin"
      end
    end
  end

  describe "GET /admin/plugins/discourse-ai/ai-logs.json" do
    it "returns lightweight logs newest first with retention metadata" do
      older_log =
        Fabricate(
          :ai_api_audit_log,
          raw_request_payload: "secret request",
          raw_response_payload: "secret response",
          created_at: 2.hours.ago,
          user:,
          llm_model:,
          language_model: llm_model.name,
          feature_name: "summarize",
          request_tokens: 10,
          response_tokens: 5,
          response_status: 200,
          duration_msecs: 1_400,
        )
      newer_log =
        Fabricate(
          :ai_api_audit_log,
          raw_request_payload: nil,
          raw_response_payload: nil,
          created_at: 1.hour.ago,
          response_status: 500,
          response_tokens: 0,
          request_attempts: [{ "status" => 500, "delay_ms" => 0 }],
        )

      get index_path, params: { include_meta: true }

      expect(response.status).to eq(200)
      expect(response.parsed_body["logs"].map { |log| log["id"] }).to eq(
        [newer_log.id, older_log.id],
      )
      expect(response.parsed_body["logs"].first).to include("has_retries" => true)
      expect(response.parsed_body["logs"].last).to include(
        "username" => user.username,
        "model_name" => llm_model.display_name,
        "duration_msecs" => 1_400,
      )
      expect(response.parsed_body["logs"].last.keys).not_to include(
        "raw_request_payload",
        "raw_response_payload",
        "decoded_response",
        "feature_context",
        "request_attempts",
      )
      expect(response.parsed_body.dig("meta", "retention")).to eq(
        "detailed_days" => 0,
        "summary_days" => 180,
      )
      expect(response.parsed_body.dig("meta", "storage", "total_bytes")).to be_positive
    end

    it "orders by persisted ID rather than backdated request start time" do
      earlier_id = Fabricate(:ai_api_audit_log, created_at: 1.minute.ago)
      later_id = Fabricate(:ai_api_audit_log, created_at: 1.day.ago)

      get index_path

      expect(response.parsed_body["logs"].map { |log| log["id"] }).to eq(
        [later_id.id, earlier_id.id],
      )
    end

    it "does not select heavyweight detail columns for the list" do
      Fabricate(:ai_api_audit_log, raw_request_payload: "secret")

      queries = track_sql_queries { get index_path }
      list_query = queries.find { |query| query.include?("AS has_retries") }

      expect(list_query).to be_present
      %w[raw_request_payload raw_response_payload feature_context request_attempts].each do |column|
        expect(list_query).not_to include(%("ai_api_audit_logs"."#{column}"))
      end
    end

    it "only returns retention metadata and filter options when requested" do
      Fabricate(:ai_api_audit_log)

      get index_path
      expect(response.parsed_body["meta"]).not_to have_key("retention")
      expect(response.parsed_body).not_to have_key("models")
      expect(response.parsed_body).not_to have_key("features")

      get index_path, params: { include_meta: true }
      expect(response.parsed_body.dig("meta", "retention")).to be_present
      expect(response.parsed_body).to have_key("models")
      expect(response.parsed_body).to have_key("features")
    end

    it "filters by outcome, retries, model, feature, user, and exact IDs" do
      matching_log =
        Fabricate(
          :ai_api_audit_log,
          user:,
          llm_model:,
          feature_name: "matching-feature",
          response_status: 500,
          response_tokens: 0,
          request_attempts: [{ "status" => 500, "delay_ms" => 0 }],
          topic_id: 123,
          post_id: 456,
        )
      Fabricate(
        :ai_api_audit_log,
        feature_name: "other-feature",
        response_status: 200,
        response_tokens: 10,
      )

      get index_path, params: { username: user.username }
      expect(response.parsed_body["logs"].map { |log| log["id"] }).to eq([matching_log.id])

      get index_path, params: { unattributed: true }
      expect(response.parsed_body["logs"].length).to eq(1)
      expect(response.parsed_body["logs"].first["feature_name"]).to eq("other-feature")

      get index_path,
          params: {
            outcome: "failed",
            has_retries: true,
            llm_id: llm_model.id,
            feature: "matching-feature",
            user_id: user.id,
          }
      expect(response.parsed_body["logs"].map { |log| log["id"] }).to eq([matching_log.id])

      get index_path,
          params: {
            topic_id: matching_log.topic_id,
            start_date: 50.years.from_now.to_date,
          }
      expect(response.parsed_body["logs"]).to be_empty

      get index_path,
          params: {
            topic_id: matching_log.topic_id,
            start_date: 1.day.ago.iso8601,
            outcome: "failed",
            has_retries: true,
            llm_id: llm_model.id,
            feature: matching_log.feature_name,
            user_id: user.id,
          }
      expect(response.parsed_body["logs"].map { |log| log["id"] }).to eq([matching_log.id])

      get index_path, params: { post_id: matching_log.post_id }
      expect(response.parsed_body["logs"].map { |log| log["id"] }).to eq([matching_log.id])

      get index_path, params: { id: matching_log.id, outcome: "successful" }
      expect(response.parsed_body["logs"]).to be_empty

      get index_path, params: { id: matching_log.id, cursor: matching_log.id, outcome: "failed" }
      expect(response.parsed_body["logs"].map { |log| log["id"] }).to eq([matching_log.id])
    end

    it "filters by seeded models and exposes them in filter metadata" do
      seeded_model = Fabricate(:seeded_model, id: -1)
      matching_log = Fabricate(:ai_api_audit_log, llm_model: seeded_model)
      Fabricate(:ai_api_audit_log, llm_model: llm_model)

      get index_path, params: { llm_id: seeded_model.id, include_meta: true }

      expect(response.status).to eq(200)
      expect(response.parsed_body["logs"].map { |returned_log| returned_log["id"] }).to eq(
        [matching_log.id],
      )
      expect(response.parsed_body["models"]).to include(
        "id" => seeded_model.id,
        "name" => seeded_model.display_name,
      )

      get index_path, params: { llm_id: -999_999 }

      expect(response.status).to eq(200)
      expect(response.parsed_body["logs"]).to be_empty
    end

    it "uses the health-check outcome semantics" do
      success_with_no_tokens =
        Fabricate(:ai_api_audit_log, response_status: 200, response_tokens: 0)
      statusless_success = Fabricate(:ai_api_audit_log, response_status: nil, response_tokens: 1)
      statusless_failure = Fabricate(:ai_api_audit_log, response_status: nil, response_tokens: 0)

      get index_path, params: { outcome: "successful" }
      expect(response.parsed_body["logs"].map { |log| log["id"] }).to contain_exactly(
        success_with_no_tokens.id,
        statusless_success.id,
      )

      get index_path, params: { outcome: "failed" }
      expect(response.parsed_body["logs"].map { |log| log["id"] }).to eq([statusless_failure.id])
    end

    it "caps a requested page size and rejects invalid limits" do
      Fabricate.times(55, :ai_api_audit_log)

      get index_path, params: { limit: 500 }
      expect(response.parsed_body["logs"].length).to eq(50)
      expect(response.parsed_body.dig("meta", "has_more")).to eq(true)

      get index_path, params: { limit: 0 }
      expect(response.status).to eq(400)
    end

    it "paginates with an ID cursor" do
      logs = Fabricate.times(52, :ai_api_audit_log)

      get index_path
      first_page = response.parsed_body

      expect(first_page["logs"].length).to eq(50)
      expect(first_page.dig("meta", "has_more")).to eq(true)
      expect(first_page.dig("meta", "next_cursor")).to eq(logs[-50].id)

      get index_path, params: { cursor: first_page.dig("meta", "next_cursor") }
      second_page = response.parsed_body

      expect(second_page["logs"].map { |log| log["id"] }).to eq(logs.first(2).reverse.map(&:id))
      expect(second_page.dig("meta", "has_more")).to eq(false)
      expect(second_page["meta"]).not_to have_key("storage")
    end

    it "paginates exact topic lookups" do
      logs = Fabricate.times(52, :ai_api_audit_log, topic_id: 789)

      get index_path, params: { topic_id: 789 }
      first_page = response.parsed_body

      expect(first_page["logs"].length).to eq(50)
      expect(first_page.dig("meta", "has_more")).to eq(true)

      get index_path, params: { topic_id: 789, cursor: first_page.dig("meta", "next_cursor") }
      second_page = response.parsed_body

      expect(second_page["logs"].map { |log| log["id"] }).to eq(logs.first(2).reverse.map(&:id))
      expect(second_page.dig("meta", "has_more")).to eq(false)
    end

    it "rejects malformed and conflicting filters" do
      get index_path, params: { outcome: "maybe" }
      expect(response.status).to eq(400)

      get index_path, params: { id: 1, topic_id: 2 }
      expect(response.status).to eq(400)

      get index_path, params: { timezone: "Not/AZone", start_date: "2026-01-01" }
      expect(response.status).to eq(400)

      get index_path, params: { has_retries: "maybe" }
      expect(response.status).to eq(400)

      get index_path, params: { include_meta: "maybe" }
      expect(response.status).to eq(400)

      get index_path, params: { start_date: "2026-02-01", end_date: "2026-01-01" }
      expect(response.status).to eq(400)

      get index_path, params: { start_date: "2024-01-01", end_date: "2026-01-02" }
      expect(response.status).to eq(400)
    end
  end

  describe "GET /admin/plugins/discourse-ai/ai-logs/:id.json" do
    it "returns raw details and truncates oversized payloads" do
      raw_response = <<~SSE
        data: {"choices":[{"delta":{"content":"decoded answer"}}]}

        data: [DONE]

      SSE
      log =
        Fabricate(
          :ai_api_audit_log,
          raw_request_payload: "a" * (1.megabyte + 10),
          raw_response_payload: raw_response,
          feature_context: {
            source: "spec",
          },
          request_attempts: [{ "status" => 0, "delay_ms" => 500 }],
          duration_msecs: 1_400,
          time_to_first_token_msecs: 320,
          estimated_cost: 0,
        )

      get "/admin/plugins/discourse-ai/ai-logs/#{log.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "id" => log.id,
        "payload_available" => true,
        "raw_request_payload_bytes" => 1.megabyte + 10,
        "raw_request_payload_truncated" => true,
        "raw_response_payload" => raw_response,
        "raw_response_payload_bytes" => raw_response.bytesize,
        "raw_response_payload_truncated" => false,
        "decoded_response" => {
          "response" => "decoded answer",
        },
        "duration_msecs" => 1_400,
        "time_to_first_token_msecs" => 320,
        "spending" => 0.0,
      )
      expect(response.parsed_body).not_to have_key("has_decoded_response")
      expect(response.parsed_body["raw_request_payload"].bytesize).to eq(1.megabyte)
    end

    it "keeps truncated multibyte payloads valid and within the response cap" do
      payload = "😀" * 300_000
      log = Fabricate(:ai_api_audit_log, raw_request_payload: payload)

      get "/admin/plugins/discourse-ai/ai-logs/#{log.id}.json"

      returned_payload = response.parsed_body["raw_request_payload"]
      expect(response.status).to eq(200)
      expect(returned_payload.valid_encoding?).to eq(true)
      expect(returned_payload.bytesize).to be <= 1.megabyte
      expect(response.parsed_body["raw_request_payload_bytes"]).to eq(payload.bytesize)
      expect(response.parsed_body["raw_request_payload_truncated"]).to eq(true)
    end

    it "falls back to an oversized response projection without partially decoding it" do
      complete_event = "data: {\"choices\":[{\"delta\":{\"content\":\"partial\"}}]}\n\n"
      raw_response = complete_event + (" " * 1.megabyte)
      log = Fabricate(:ai_api_audit_log, raw_response_payload: raw_response)

      get "/admin/plugins/discourse-ai/ai-logs/#{log.id}.json"

      returned_payload = response.parsed_body["raw_response_payload"]
      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "raw_response_payload_bytes" => raw_response.bytesize,
        "raw_response_payload_truncated" => true,
        "decoded_response" => nil,
      )
      expect(returned_payload.bytesize).to eq(1.megabyte)
    end

    it "returns a payload-unavailable record and 404 for a missing record" do
      log = Fabricate(:ai_api_audit_log, raw_request_payload: nil, raw_response_payload: nil)

      get "/admin/plugins/discourse-ai/ai-logs/#{log.id}.json"
      expect(response.parsed_body).to include(
        "payload_available" => false,
        "raw_request_payload" => nil,
        "raw_response_payload" => nil,
        "decoded_response" => nil,
      )

      get "/admin/plugins/discourse-ai/ai-logs/#{log.id + 100_000}.json"
      expect(response.status).to eq(404)
    end
  end

  describe "PUT /admin/plugins/discourse-ai/ai-logs/retention.json" do
    let(:path) { "/admin/plugins/discourse-ai/ai-logs/retention.json" }

    it "updates both retention settings" do
      SiteSetting.ai_audit_logs_purge_after_days = 90

      expect do put path, params: { detailed_days: 30, summary_days: 180 } end.to change {
        UserHistory.where(action: UserHistory.actions[:change_site_setting]).count
      }.by(2)

      expect(response.status).to eq(200)
      expect(response.parsed_body["retention"]).to eq("detailed_days" => 30, "summary_days" => 180)
      expect(SiteSetting.ai_audit_logs_detailed_retention_days).to eq(30)
      expect(SiteSetting.ai_audit_logs_purge_after_days).to eq(180)
    end

    it "supports keeping complete logs forever" do
      SiteSetting.ai_audit_logs_detailed_retention_days = 30
      SiteSetting.ai_audit_logs_purge_after_days = 180

      put path, params: { detailed_days: 0, summary_days: 0 }

      expect(response.status).to eq(200)
      expect(response.parsed_body["retention"]).to eq("detailed_days" => 0, "summary_days" => 0)
    end

    it "supports full detail until finite deletion" do
      put path, params: { detailed_days: 0, summary_days: 180 }

      expect(response.status).to eq(200)
      expect(response.parsed_body["retention"]).to eq("detailed_days" => 0, "summary_days" => 180)
    end

    it "rejects impossible and malformed pairs" do
      put path, params: { detailed_days: 181, summary_days: 180 }
      expect(response.status).to eq(400)

      put path, params: { detailed_days: -1, summary_days: 0 }
      expect(response.status).to eq(400)

      put path, params: { detailed_days: 0, summary_days: 36_501 }
      expect(response.status).to eq(400)
    end

    it "does not partially update the pair when a setting is invalid" do
      SiteSetting.ai_audit_logs_detailed_retention_days = 30
      SiteSetting.ai_audit_logs_purge_after_days = 180

      put path, params: { detailed_days: 10, summary_days: 36_501 }

      expect(response.status).to eq(400)
      expect(SiteSetting.ai_audit_logs_detailed_retention_days).to eq(30)
      expect(SiteSetting.ai_audit_logs_purge_after_days).to eq(180)
    end

    it "rejects requests without a CSRF token" do
      ActionController::Base.allow_forgery_protection = true

      put path, params: { detailed_days: 30, summary_days: 180 }

      expect(response.status).to eq(403)
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
  end
end
