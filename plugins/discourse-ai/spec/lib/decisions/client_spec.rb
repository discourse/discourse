# frozen_string_literal: true

RSpec.describe DiscourseAi::Decisions::Client do
  fab!(:decision_model)
  fab!(:user)

  let(:questions) do
    [
      { name: "urgent", type: "yes_no", instructions: "Urgent?" },
      { name: "team", type: "choice", instructions: "Who?", choices: %w[billing returns] },
      { name: "severity", type: "score", instructions: "How bad?", levels: %w[low medium high] },
    ]
  end
  let(:response_body) do
    {
      model: "jev-1.13.0",
      answers: {
        urgent: {
          type: "noul",
          noul: 0.95,
        },
        team: {
          type: "choice",
          choice: "billing",
          probabilities: {
            billing: 0.9,
            returns: 0.1,
          },
          confidence: 0.8,
        },
        severity: {
          type: "score",
          score: 1.6,
          probabilities: {
            "0" => 0.1,
            "1" => 0.1,
            "2" => 0.8,
          },
          confidence: nil,
        },
      },
      usage: {
        input_tokens: 296,
        output_tokens: 0,
      },
    }
  end
  let(:client) { described_class.new(decision_model) }

  before do
    enable_current_plugin
    described_class.any_instance.stubs(:sleep)
  end

  describe "#decide" do
    it "sends System One questions and returns typed answers, with one audit and usage row" do
      request =
        stub_request(:post, decision_model.url).with(
          headers: {
            "Authorization" => "Bearer #{decision_model.api_key}",
          },
          body: {
            model: "jev-latest",
            state: {
              text: "Help!",
            },
            questions: {
              urgent: {
                type: "noul",
                instructions: "Urgent?",
              },
              team: {
                type: "choice",
                instructions: "Who?",
                criteria: {
                  billing: "billing",
                  returns: "returns",
                },
              },
              severity: {
                type: "score",
                instructions: "How bad?",
                criteria: %w[low medium high],
              },
            },
          }.to_json,
        ).to_return(body: response_body.to_json)

      expect {
        @result = client.decide({ text: "Help!" }, questions:, feature_name: "workflow", user:)
      }.to change { AiApiAuditLog.count }.by(1).and change { AiApiRequestStat.count }.by(1)
      result = @result
      expect(request).to have_been_requested.once
      expect(result["urgent"]).to be_a(DiscourseAi::Decisions::Answers::YesNo)
      expect(result["urgent"].to_h).to eq(type: "yes_no", probability: 0.95)
      expect(result["team"]).to have_attributes(
        choice: "billing",
        probabilities: {
          "billing" => 0.9,
          "returns" => 0.1,
        },
        confidence: 0.8,
      )
      expect(result["severity"]).to have_attributes(
        score: 1.6,
        level: "high",
        probabilities: {
          "low" => 0.1,
          "medium" => 0.1,
          "high" => 0.8,
        },
        confidence: nil,
      )
      expect(result["team"].probabilities).to be_frozen
      expect(result["severity"].probabilities).to be_frozen
      expect(result.provider_model).to eq("jev-1.13.0")
      log = AiApiAuditLog.find(result.audit_log_id)
      expect(log).to have_attributes(
        provider_id: AiApiAuditLog::Provider::SystemOne,
        user_id: user.id,
        feature_name: "workflow",
        language_model: "jev-latest",
        request_tokens: 296,
        response_tokens: 0,
        response_status: 200,
        request_attempts: nil,
      )
      expect(AiApiRequestStat.last).to have_attributes(
        usage_count: 1,
        llm_id: nil,
        request_tokens: 296,
        provider_id: AiApiAuditLog::Provider::SystemOne,
      )
    end

    it "omits authorization when the endpoint has no credential" do
      decision_model.update!(ai_secret: nil)
      request =
        stub_request(:post, decision_model.url)
          .with { |req| !req.headers.key?("Authorization") }
          .to_return(body: response_body.to_json)
      client.decide("Hello", questions:, feature_name: "test")
      expect(request).to have_been_requested.once
    end

    it "returns explicit refusals without discarding other answers" do
      response_body[:answers][:urgent] = { type: "refusal", reason: "Cannot answer" }
      stub_request(:post, decision_model.url).to_return(body: response_body.to_json)
      result = client.decide("Hello", questions:, feature_name: "test")
      expect(result.refusals.map(&:name)).to eq(["urgent"])
      expect(result["urgent"].to_h).to eq(type: "refusal", reason: "Cannot answer")
      expect(result["team"].choice).to eq("billing")
    end

    it "rejects malformed answers, probabilities and confidence without retrying" do
      malformed = [
        [],
        response_body.deep_dup.tap { |body| body[:answers] = [] },
        response_body.deep_dup.tap { |body| body[:answers][:urgent] = nil },
        response_body.deep_dup.tap do |body|
          body[:answers][:urgent] = { type: "refusal", reason: 1 }
        end,
        response_body.deep_dup.tap { |body| body[:answers].delete(:urgent) },
        response_body.deep_dup.tap { |body| body[:answers][:extra] = body[:answers][:urgent] },
        response_body.deep_dup.tap { |body| body[:answers][:urgent][:type] = "predicate" },
        response_body.deep_dup.tap { |body| body[:answers][:urgent][:noul] = 1.1 },
        response_body.deep_dup.tap { |body| body[:answers][:team][:choice] = "other" },
        response_body.deep_dup.tap do |body|
          body[:answers][:team][:probabilities].delete(:returns)
        end,
        response_body.deep_dup.tap do |body|
          body[:answers][:severity][:probabilities]["0"] = "0.1"
        end,
        response_body.deep_dup.tap { |body| body[:answers][:severity][:probabilities]["3"] = 0.0 },
        response_body.deep_dup.tap { |body| body[:answers][:team][:confidence] = -0.1 },
        response_body.deep_dup.tap { |body| body[:answers][:severity][:score] = 3 },
      ]
      request =
        stub_request(:post, decision_model.url).to_return(
          *malformed.map { |body| { body: body.to_json } },
        )
      malformed.each do
        expect { client.decide("Hello", questions:, feature_name: "test") }.to raise_error(
          DiscourseAi::Decisions::RequestFailed,
        ) do |error|
          expect(error).to have_attributes(http_status: 200, retryable?: false)
        end
      end
      expect(request).to have_been_requested.times(malformed.size)
      expect(AiApiAuditLog.count).to eq(malformed.size)
      expect(AiApiRequestStat.count).to eq(malformed.size)
    end

    it "rejects invalid JSON in successful responses without retrying" do
      request = stub_request(:post, decision_model.url).to_return(body: "not JSON")
      expect { client.decide("Hello", questions:, feature_name: "test") }.to raise_error(
        DiscourseAi::Decisions::RequestFailed,
        /invalid JSON/,
      )
      expect(request).to have_been_requested.once
      expect(AiApiAuditLog.last.request_attempts).to be_nil
    end

    it "retains the last response body when the final attempt fails on the network" do
      body = { message: "Busy" }.to_json
      request =
        stub_request(:post, decision_model.url)
          .to_return(status: 503, body:)
          .then
          .to_raise(EOFError)
      expect {
        described_class.new(decision_model, max_attempts: 2).decide(
          "Hello",
          questions:,
          feature_name: "test",
        )
      }.to raise_error(DiscourseAi::Decisions::RequestFailed)
      expect(request).to have_been_requested.times(2)
      expect(AiApiAuditLog.last).to have_attributes(
        response_status: 0,
        raw_response_payload: body,
        request_attempts: [{ "status" => 503, "delay_ms" => 1000 }],
      )
      expect(AiApiRequestStat.count).to eq(1)
    end

    it "retries HTTP and network errors with capped delays and records only retried attempts" do
      request =
        stub_request(:post, decision_model.url)
          .to_return(status: 429, headers: { "Retry-After" => "20" })
          .then
          .to_raise(Timeout::Error)
          .then
          .to_return(body: response_body.to_json)
      expect { @result = client.decide("Hello", questions:, feature_name: "test") }.to change {
        AiApiRequestStat.count
      }.by(1)
      expect(request).to have_been_requested.times(3)
      log = AiApiAuditLog.find(@result.audit_log_id)
      expect(log.request_attempts).to eq(
        [{ "status" => 429, "delay_ms" => 5000 }, { "status" => 0, "delay_ms" => 2000 }],
      )
      expect(log.response_status).to eq(200)
      expect(log.raw_response_payload).to eq(response_body.to_json)
    end

    it "stops after max_attempts and records failures once" do
      request =
        stub_request(:post, decision_model.url).to_return(
          status: 503,
          body: { detail: "Busy" }.to_json,
        )
      expect { client.decide("Hello", questions:, feature_name: "test") }.to raise_error(
        DiscourseAi::Decisions::RequestFailed,
      ) { |error| expect(error).to have_attributes(http_status: 503, retryable?: true) }
      expect(request).to have_been_requested.times(3)
      expect(AiApiAuditLog.last.request_attempts).to eq(
        [{ "status" => 503, "delay_ms" => 1000 }, { "status" => 503, "delay_ms" => 2000 }],
      )
      expect(AiApiRequestStat.count).to eq(1)
    end

    it "does not retry SSRF failures" do
      WebMock.enable!(except: [:final_destination])
      FinalDestination::SSRFDetector.allow_ip_lookups_in_test!
      stub_ip_lookup(URI(decision_model.url).host, ["169.254.169.254"])

      expect { client.decide("Hello", questions:, feature_name: "test") }.to raise_error(
        DiscourseAi::Decisions::RequestFailed,
        /all resolved IPs were disallowed/,
      ) { |error| expect(error).not_to be_retryable }
      expect(AiApiAuditLog.last).to have_attributes(response_status: 0, request_attempts: nil)
      expect(AiApiRequestStat.count).to eq(1)
    ensure
      WebMock.enable!
      FinalDestination::SSRFDetector.disallow_ip_lookups_in_test!
    end

    it "sanitizes provider errors and does not retry rejected requests" do
      leaked = "#{decision_model.api_key} Bearer xyz-secret sk-provider-secret key-other-secret"
      request =
        stub_request(:post, decision_model.url).to_return(
          status: 401,
          body: { error: { message: "Rejected #{leaked} #{"x" * 600}" } }.to_json,
        )
      expect { client.decide("Hello", questions:, feature_name: "test") }.to raise_error(
        DiscourseAi::Decisions::RequestFailed,
      ) do |error|
        expect(error.message).to start_with("Request failed with status 401: Rejected")
        expect(error.message).not_to include(
          decision_model.api_key,
          "xyz-secret",
          "sk-provider-secret",
          "key-other-secret",
        )
        expect(error.message.size).to be <= 500
        expect(error).to have_attributes(http_status: 401, retryable?: false)
      end
      expect(request).to have_been_requested.once
      expect(AiApiAuditLog.last).to have_attributes(response_status: 401, request_attempts: nil)
      expect(AiApiAuditLog.last.raw_response_payload).not_to include(
        decision_model.api_key,
        "xyz-secret",
        "sk-provider-secret",
      )
    end

    it "redacts echoed custom-header values from provider errors, network errors and audit logs" do
      header_value = 'private"header\\value'
      decision_model.update!(custom_headers: [{ name: "X-Custom-Key", value: header_value }])
      request =
        stub_request(:post, decision_model.url)
          .to_return(status: 401, body: { error: { message: "Rejected #{header_value}" } }.to_json)
          .then
          .to_raise(IOError.new("Echoed #{header_value}"))

      2.times do
        expect {
          described_class.new(decision_model, max_attempts: 1).decide(
            "Hello",
            questions:,
            feature_name: "test",
          )
        }.to raise_error(DiscourseAi::Decisions::RequestFailed) do |error|
          expect(error.message).to include("[redacted]")
          expect(error.message).not_to include(header_value)
        end
      end

      expect(request).to have_been_requested.twice
      log = AiApiAuditLog.find_by!(response_status: 401)
      expect(JSON.parse(log.raw_response_payload).dig("error", "message")).to eq(
        "Rejected [redacted]",
      )
    end

    it "redacts short custom-header echoes in stored successful responses without changing answers" do
      header_value = "xy"
      decision_model.update!(custom_headers: [{ name: "X-Custom-Key", value: header_value }])
      response_body[:answers][:urgent] = { type: "refusal", reason: header_value }
      stub_request(:post, decision_model.url).to_return(body: response_body.to_json)

      result = client.decide("Hello", questions:, feature_name: "test")

      expect(result["urgent"].reason).to eq(header_value)
      expect(AiApiAuditLog.find(result.audit_log_id).raw_response_payload).not_to include(
        header_value,
      )
    end

    it "redacts only the stored response, never the answers" do
      key_questions = [
        { name: "team", type: "choice", instructions: "Who?", choices: %w[key-account other] },
      ]
      body = {
        model: "jev",
        answers: {
          team: {
            type: "choice",
            choice: "key-account",
            probabilities: {
              "key-account" => 0.9,
              "other" => 0.1,
            },
            confidence: 0.8,
          },
        },
      }
      stub_request(:post, decision_model.url).to_return(body: body.to_json)

      result = client.decide("Hello", questions: key_questions, feature_name: "test")

      expect(result["team"].choice).to eq("key-account")
      expect(AiApiAuditLog.last.raw_response_payload).not_to include("key-account")
    end

    it "unwraps Cloudflare Workers AI responses and errors" do
      envelope = { result: response_body, success: true, errors: [], messages: [] }
      cloudflare_error = {
        errors: [
          { message: "AiError: AiError: image must be an embedded base64 data URI", code: 5012 },
        ],
        success: false,
        result: {
        },
      }
      stub_request(:post, decision_model.url).to_return(
        { body: envelope.to_json },
        { status: 422, body: cloudflare_error.to_json },
      )

      expect(client.decide("Hello", questions:, feature_name: "test")["urgent"].probability).to eq(
        0.95,
      )
      expect { client.decide("Hello", questions:, feature_name: "test") }.to raise_error(
        DiscourseAi::Decisions::RequestFailed,
        "Request failed with status 422: image must be an embedded base64 data URI",
      )
    end

    it "preserves Cloudflare flags and numeric probabilities in response audits" do
      decision_model.update!(
        custom_headers: [
          { name: "X-Images", value: "true" },
          { name: "X-Other-Flag", value: "false" },
          { name: "X-Count", value: "1" },
        ],
      )
      envelope = { result: response_body, success: true, errors: [], messages: [] }
      stub_request(:post, decision_model.url).to_return(body: envelope.to_json)

      result = client.decide("Hello", questions:, feature_name: "test")

      expect(result["urgent"].probability).to eq(0.95)
      expect(JSON.parse(AiApiAuditLog.find(result.audit_log_id).raw_response_payload)).to eq(
        JSON.parse(envelope.to_json),
      )
    end

    it "keeps words containing flag values intact in HTTP and network diagnostics" do
      decision_model.update!(custom_headers: [{ name: "X-Images", value: "true" }])
      message = "image configuration is untrue"
      request =
        stub_request(:post, decision_model.url)
          .to_return(status: 422, body: { error: message }.to_json)
          .then
          .to_raise(IOError.new(message))

      [
        "Request failed with status 422: #{message}",
        "Request failed: #{message}",
      ].each do |expected|
        expect { client.decide("Hello", questions:, feature_name: "test") }.to raise_error(
          DiscourseAi::Decisions::RequestFailed,
          expected,
        )
      end

      expect(request).to have_been_requested.twice
      expect(JSON.parse(AiApiAuditLog.find_by!(response_status: 422).raw_response_payload)).to eq(
        "error" => message,
      )
    end

    it "keeps valid answers when usage counts are unusable" do
      body =
        response_body.deep_dup.tap do |payload|
          payload[:usage] = { input_tokens: 296.0, output_tokens: 3_000_000_000 }
        end
      stub_request(:post, decision_model.url).to_return(body: body.to_json)

      result = client.decide("Hello", questions:, feature_name: "test")

      expect([result.input_tokens, result.output_tokens]).to eq([296, nil])
      expect(AiApiAuditLog.last).to have_attributes(request_tokens: 296, response_tokens: nil)
    end

    it "sends legacy images separately from unchanged string and structured state and redacts image audits" do
      decision_model.update!(vision_enabled: true)
      images = %w[data:image/png;base64,AAAA data:image/jpeg;base64,BBBB]
      [images.first + "x" * 20_001, { posts: [{ text: "Hello" }] }].each do |state|
        sent = nil
        request =
          stub_request(:post, decision_model.url)
            .with do |req|
              sent = JSON.parse(req.body)
              sent["state"] == JSON.parse(state.to_json) && sent["images"] == images &&
                !sent.key?("assets")
            end
            .to_return(body: response_body.to_json)

        result = client.decide(state, questions:, images:, feature_name: "test")

        payload = JSON.parse(AiApiAuditLog.find(result.audit_log_id).raw_request_payload)
        expect(payload).to eq(
          sent.merge(
            "images" => ["[redacted image/png, 3 Bytes]", "[redacted image/jpeg, 3 Bytes]"],
          ),
        )
        expect(images).to eq(%w[data:image/png;base64,AAAA data:image/jpeg;base64,BBBB])
        expect(request).to have_been_requested
      end
    end

    it "serializes Time values in structured state consistently on the wire and in audits" do
      state = { posts: [{ text: "Hello", created_at: Time.utc(2026, 10, 14, 12, 34, 56) }] }
      sent = nil
      request =
        stub_request(:post, decision_model.url)
          .with do |req|
            sent = JSON.parse(req.body)
            sent["state"] == JSON.parse(state.to_json)
          end
          .to_return(body: response_body.to_json)

      result = client.decide(state, questions:, feature_name: "test")

      expect(sent.dig("state", "posts", 0, "created_at")).to eq("2026-10-14T12:34:56.000Z")
      expect(JSON.parse(AiApiAuditLog.find(result.audit_log_id).raw_request_payload)).to eq(sent)
      expect(request).to have_been_requested.once
    end

    it "resolves SRV endpoints and preserves the path" do
      decision_model.update!(url: "srv://_decisions._tcp.example.com/v1/decide?region=eu")
      DiscourseAi::Utils::DnsSrv
        .stubs(:lookup)
        .with("_decisions._tcp.example.com")
        .returns(Resolv::DNS::Resource::IN::SRV.new(0, 0, 8443, "engine.example.com"))
      request =
        stub_request(:post, "https://engine.example.com:8443/v1/decide?region=eu").to_return(
          body: response_body.to_json,
        )
      client.decide("Hello", questions:, feature_name: "test")
      expect(request).to have_been_requested.once
    end

    it "does not log when SRV discovery fails before transport" do
      decision_model.update!(url: "srv://missing.example.com/path")
      DiscourseAi::Utils::DnsSrv.stubs(:lookup).returns(nil)
      expect { client.decide("Hello", questions:, feature_name: "test") }.to raise_error(
        DiscourseAi::Decisions::RequestFailed,
      ) { |error| expect(error).not_to be_retryable }
      expect(AiApiAuditLog.count).to eq(0)

      DiscourseAi::Utils::DnsSrv.stubs(:lookup).raises(Resolv::ResolvTimeout)
      expect { client.decide("Hello", questions:, feature_name: "test") }.to raise_error(
        DiscourseAi::Decisions::RequestFailed,
        /SRV lookup/,
      ) { |error| expect(error).not_to be_retryable }
      expect(AiApiAuditLog.count).to eq(0)
    end

    it "validates requests before transport or audit logging" do
      [
        { feature_name: "" },
        { questions: [] },
        { questions: questions + [questions.first] },
        { images: ["https://example.com/image.png"] },
        { images: ["data:image/png,AAAA"] },
        { images: ["data:image/png;base64,AAAA"] },
        { images: [123] },
        { images: nil },
        { questions: [{ name: "invalid-name", type: "yes_no", instructions: "Question?" }] },
      ].each do |overrides|
        expect {
          client.decide("Hello", **{ questions:, feature_name: "test" }.merge(overrides))
        }.to raise_error(DiscourseAi::Decisions::InvalidRequest)
      end
      ["", nil, {}, [], 123].each do |state|
        expect { client.decide(state, questions:, feature_name: "test") }.to raise_error(
          DiscourseAi::Decisions::InvalidRequest,
        )
      end
      expect(AiApiAuditLog.count).to eq(0)
      expect(AiApiRequestStat.count).to eq(0)
    end

    it "uses a single attempt when configured" do
      request = stub_request(:post, decision_model.url).to_return(status: 529)
      expect {
        described_class.new(decision_model, timeout: 10, max_attempts: 1).decide(
          "Hello",
          questions:,
          feature_name: "test",
        )
      }.to raise_error(DiscourseAi::Decisions::RequestFailed)
      expect(request).to have_been_requested.once
      expect(AiApiAuditLog.last.request_attempts).to be_nil
    end
  end

  describe "#decide with credits" do
    fab!(:seeded_model) do
      Fabricate(:decision_model, id: -1, ai_secret: nil, api_key: "seeded-key")
    end
    fab!(:allocation) do
      Fabricate(
        :decision_model_credit_allocation,
        decision_model: seeded_model,
        daily_credits: 1000,
      )
    end

    let(:client) { described_class.new(seeded_model) }

    it "deducts the reported tokens from the seeded model's allocation" do
      stub_request(:post, seeded_model.url).with(
        headers: {
          "Authorization" => "Bearer seeded-key",
        },
      ).to_return(body: response_body.to_json)

      client.decide("Hello", questions:, feature_name: "workflow")

      expect(allocation.reload.daily_used).to eq(296)
    end

    it "estimates tokens per question, counting state and images in each, when the provider omits usage" do
      seeded_model.update!(vision_enabled: true)
      stub_request(:post, seeded_model.url).to_return(body: response_body.except(:usage).to_json)

      client.decide(
        "Hello",
        questions:,
        images: %w[data:image/png;base64,AAAA],
        feature_name: "workflow",
      )

      per_question_floor =
        described_class::ESTIMATED_TOKENS_PER_IMAGE + described_class::ESTIMATED_TOKENS_PER_QUESTION
      expect(allocation.reload.daily_used).to be_between(
        questions.size * per_question_floor,
        questions.size * (per_question_floor + 20),
      )
    end

    it "does not deduct credits when the request fails" do
      stub_request(:post, seeded_model.url).to_return(status: 400)

      expect { client.decide("Hello", questions:, feature_name: "workflow") }.to raise_error(
        DiscourseAi::Decisions::RequestFailed,
      )
      expect(allocation.reload.daily_used).to eq(0)
    end

    it "refuses before transport, even with canned answers, once credits are used up" do
      DecisionModelCreditAllocation.deduct_credits!(seeded_model, "workflow", 1000)
      request = stub_request(:post, seeded_model.url)

      expect { client.decide("Hello", questions:, feature_name: "workflow") }.to raise_error(
        DiscourseAi::Decisions::CreditLimitExceeded,
      )
      DiscourseAi::Decisions.with_canned_answers(urgent: true, team: "billing", severity: "low") do
        expect { client.decide("Hello", questions:, feature_name: "workflow") }.to raise_error(
          DiscourseAi::Decisions::CreditLimitExceeded,
        )
      end
      expect(request).not_to have_been_requested
      expect(AiApiAuditLog.count).to eq(0)
    end
  end

  describe "#decide with TypeSafe" do
    before { decision_model.update!(provider: "typesafe", vision_enabled: true) }

    after { DiscourseAi::RequestHeaders.reset! }

    it "sends PNG and JPEG assets with stable references and redacts only their binary audit data" do
      image = "data:image/png;base64,AAAA"
      jpeg = "data:image/jpeg;base64,BBBB"
      state = image + "x" * 20_001
      sent = nil
      request =
        stub_request(:post, decision_model.url)
          .with do |req|
            sent = JSON.parse(req.body)
            references = sent.dig("state", "images")
            sent.dig("state", "text") == state && references.is_a?(Array) && references.size == 2 &&
              references.uniq.size == 2 &&
              references.all? { |reference| reference.match?(/\A[0-9a-f-]{36}\z/) } &&
              sent["assets"].keys == references && !sent.key?("images") &&
              sent["assets"].values ==
                [
                  { "type" => "image", "format" => "png", "data_base64" => "AAAA" },
                  { "type" => "image", "format" => "jpeg", "data_base64" => "BBBB" },
                ]
          end
          .to_return(body: response_body.to_json)

      result = client.decide(state, questions:, images: [image, jpeg], feature_name: "test")

      payload = JSON.parse(AiApiAuditLog.find(result.audit_log_id).raw_request_payload)
      expect(payload["state"]).to eq(sent["state"])
      expect(payload["assets"].keys).to eq(sent["assets"].keys)
      expect(payload["assets"].values).to eq(
        [
          {
            "type" => "image",
            "format" => "png",
            "data_base64" => "[redacted image/png, 3 Bytes]",
          },
          {
            "type" => "image",
            "format" => "jpeg",
            "data_base64" => "[redacted image/jpeg, 3 Bytes]",
          },
        ],
      )
      expect(payload["questions"]).to eq(sent["questions"])
      expect(payload).not_to have_key("images")
      expect(request).to have_been_requested.once
    end

    it "preserves structured state and normalizes the JPEG alias for image assets" do
      state = { posts: [{ text: "Hello" }] }
      request =
        stub_request(:post, decision_model.url)
          .with do |req|
            payload = JSON.parse(req.body)
            reference = payload.dig("state", "images", 0)
            payload.dig("state", "text") == state.deep_stringify_keys &&
              payload["assets"] ==
                { reference => { "type" => "image", "format" => "jpeg", "data_base64" => "AAAA" } }
          end
          .to_return(body: response_body.to_json)

      client.decide(state, questions:, images: ["data:image/jpg;base64,AAAA"], feature_name: "test")

      expect(request).to have_been_requested.once
    end

    it "rejects unsupported image formats before transport" do
      expect {
        client.decide(
          "Hello",
          questions:,
          images: ["data:image/webp;base64,AAAA"],
          feature_name: "test",
        )
      }.to raise_error(DiscourseAi::Decisions::InvalidRequest, /PNG or JPEG/)
      expect(AiApiAuditLog.count).to eq(0)
    end

    it "preserves text-only string and structured state without adding image fields" do
      ["Hello", { posts: [{ text: "Hello" }] }].each do |state|
        sent = nil
        request =
          stub_request(:post, decision_model.url)
            .with do |req|
              sent = JSON.parse(req.body)
              sent["state"] == JSON.parse(state.to_json) && (sent.keys & %w[images assets]).empty?
            end
            .to_return(body: response_body.to_json)

        result = client.decide(state, questions:, feature_name: "test")

        expect(result["urgent"].probability).to eq(0.95)
        log = AiApiAuditLog.find(result.audit_log_id)
        expect(log.provider_id).to eq(AiApiAuditLog::Provider::SystemOne)
        expect(JSON.parse(log.raw_request_payload)).to eq(sent)
        expect(request).to have_been_requested
      end
    end

    it "shares custom and registered routing headers with System One" do
      decision_model.update!(custom_headers: [{ name: "X-Custom-Key", value: "sensitive" }])
      DiscourseAi::RequestHeaders.register { |_context| { "X-Test-Feature" => "workflow" } }
      request =
        stub_request(:post, decision_model.url).with(
          headers: {
            "X-Custom-Key" => "sensitive",
            "X-Test-Feature" => "workflow",
            "Content-Type" => "application/json",
            "Authorization" => "Bearer #{decision_model.api_key}",
          },
        ).to_return(body: response_body.to_json)

      client.decide("Hello", questions:, feature_name: "workflow")

      expect(request).to have_been_requested.once
    end
  end

  describe "#decide with OpenAI" do
    let(:open_ai_body) do
      {
        model: "gpt-6-luna-version",
        answers: [
          { type: "predicate", name: "urgent", probability: 0.2 },
          {
            type: "choice",
            name: "team",
            choice: "returns",
            probabilities: [
              { value: "returns", probability: 0.7 },
              { value: "billing", probability: 0.3 },
            ],
            confidence: 0.6,
          },
          {
            type: "score",
            name: "severity",
            score: 0.1,
            probabilities: [
              { value: 2, label: "high", probability: 0.0 },
              { value: 0, probability: 0.9 },
              { value: 1, probability: 0.1 },
            ],
            confidence: 0.85,
          },
        ],
      }
    end

    before do
      decision_model.update!(
        provider: "open_ai",
        name: "gpt-6-luna",
        url: "https://api.openai.com/v1/decisions",
        vision_enabled: true,
      )
    end

    it "sends typed questions and images, normalizes score order and redacts audit images" do
      image = "data:image/png;base64,AAAA"
      request =
        stub_request(:post, decision_model.url).with(
          body: {
            model: "gpt-6-luna",
            input: [
              {
                role: "user",
                content: [
                  { type: "input_text", text: '["Help!"]' },
                  { type: "input_image", image_url: image },
                ],
              },
            ],
            questions: [
              { type: "predicate", name: "urgent", instructions: "Urgent?" },
              {
                type: "choice",
                name: "team",
                instructions: "Who?",
                choices: [{ value: "billing" }, { value: "returns" }],
              },
              {
                type: "score",
                name: "severity",
                instructions: "How bad?",
                levels: [{ label: "low" }, { label: "medium" }, { label: "high" }],
              },
            ],
          }.to_json,
        ).to_return(body: open_ai_body.to_json)
      result = client.decide(["Help!"], questions:, images: [image], feature_name: "test")
      expect(request).to have_been_requested.once
      expect(result["urgent"].probability).to eq(0.2)
      expect(result["team"]).to have_attributes(
        choice: "returns",
        probabilities: {
          "billing" => 0.3,
          "returns" => 0.7,
        },
        confidence: 0.6,
      )
      expect(result["severity"]).to have_attributes(
        score: 0.1,
        level: "low",
        probabilities: {
          "low" => 0.9,
          "medium" => 0.1,
          "high" => 0.0,
        },
      )
      log = AiApiAuditLog.find(result.audit_log_id)
      expect(log.provider_id).to eq(AiApiAuditLog::Provider::OpenAiDecisions)
      expect(log.raw_request_payload).not_to include(image)
      expect(
        JSON.parse(log.raw_request_payload).dig("input", 0, "content", 1, "image_url"),
      ).to match(%r{\A\[redacted image/\w+, [\d.]+ \w+\]\z})
    end

    it "redacts only OpenAI image content and preserves matching image text in the state" do
      image = "data:image/png;base64,AAAA"
      state = image + "x" * 20_001
      request =
        stub_request(:post, decision_model.url)
          .with do |req|
            payload = JSON.parse(req.body)
            payload.dig("input", 0, "content") ==
              [
                { "type" => "input_text", "text" => state },
                { "type" => "input_image", "image_url" => image },
              ] && !payload.key?("assets")
          end
          .to_return(body: open_ai_body.to_json)

      result = client.decide(state, questions:, images: [image], feature_name: "test")

      payload = JSON.parse(AiApiAuditLog.find(result.audit_log_id).raw_request_payload)
      expect(payload.dig("input", 0, "content")).to eq(
        [
          { "type" => "input_text", "text" => state },
          { "type" => "input_image", "image_url" => "[redacted image/png, 3 Bytes]" },
        ],
      )
      expect(request).to have_been_requested.once
    end

    it "returns refusal text" do
      open_ai_body[:answers][0] = { name: "urgent", type: "refusal", refusal: "Cannot answer" }
      stub_request(:post, decision_model.url).to_return(body: open_ai_body.to_json)
      expect(client.decide("Hello", questions:, feature_name: "test")["urgent"].to_h).to eq(
        type: "refusal",
        reason: "Cannot answer",
      )
    end

    it "rejects duplicate answers and missing or duplicate level probabilities" do
      malformed = [
        open_ai_body.deep_dup.tap { |body| body[:answers] = {} },
        open_ai_body.deep_dup.tap { |body| body[:answers][1][:probabilities] = {} },
        open_ai_body.deep_dup.tap { |body| body[:answers] << body[:answers].first },
        open_ai_body.deep_dup.tap { |body| body[:answers][2][:probabilities].pop },
        open_ai_body.deep_dup.tap do |body|
          body[:answers][2][:probabilities] << body[:answers][2][:probabilities].first
        end,
        open_ai_body.deep_dup.tap { |body| body[:answers][0][:probability] = nil },
      ]
      request =
        stub_request(:post, decision_model.url).to_return(
          *malformed.map { |body| { body: body.to_json } },
        )
      malformed.each do
        expect { client.decide("Hello", questions:, feature_name: "test") }.to raise_error(
          DiscourseAi::Decisions::RequestFailed,
        ) { |error| expect(error).not_to be_retryable }
      end
      expect(request).to have_been_requested.times(malformed.size)
    end
  end

  describe "request header providers" do
    after { DiscourseAi::RequestHeaders.reset! }

    it "sends persisted custom headers with System One requests without including them in audit payloads" do
      headers = [{ "name" => "X-Custom-Key", "value" => "sensitive-header-value" }]
      decision_model.update!(custom_headers: headers)
      decision_model.reload
      request =
        stub_request(:post, decision_model.url).with(
          headers: {
            "X-Custom-Key" => headers.first["value"],
            "Content-Type" => "application/json",
            "Authorization" => "Bearer #{decision_model.api_key}",
          },
        ).to_return(body: response_body.to_json)

      result = client.decide("Hello", questions:, feature_name: "workflow")

      expect(request).to have_been_requested.once
      expect(AiApiAuditLog.find(result.audit_log_id).raw_request_payload).not_to include(
        headers.first["value"],
      )
    end

    it "keeps registered routing headers authoritative across case variants" do
      decision_model.update!(
        custom_headers: [
          { name: "x-test-feature", value: "custom override" },
          { name: "X-Unrelated", value: "custom value" },
        ],
      )
      DiscourseAi::RequestHeaders.register { |_context| { "X-Test-Feature" => "registered" } }
      request =
        stub_request(:post, decision_model.url).with(
          headers: {
            "X-Test-Feature" => "registered",
            "X-Unrelated" => "custom value",
          },
        ).to_return(body: response_body.to_json)

      client.decide("Hello", questions:, feature_name: "workflow")

      expect(request).to have_been_requested.once
    end

    it "ignores unsafe custom headers stored without validation" do
      decision_model.update_columns(
        custom_headers: [
          { name: "aUtHoRiZaTiOn", value: "attacker" },
          { name: "content-TYPE", value: "text/plain" },
          { name: "Host", value: "attacker.example.com" },
          { name: "X-Unsafe", value: "bad\r\nInjected: value" },
        ],
      )
      request =
        stub_request(:post, decision_model.url)
          .with(
            headers: {
              "Authorization" => "Bearer #{decision_model.api_key}",
              "Content-Type" => "application/json",
            },
          )
          .with do |req|
            !req.headers.key?("X-Unsafe") && req.headers["Host"] != "attacker.example.com"
          end
          .to_return(body: response_body.to_json)

      client.decide("Hello", questions:, feature_name: "workflow")

      expect(request).to have_been_requested.once
    end

    it "sends registered routing headers with System One decisions" do
      captured = nil
      DiscourseAi::RequestHeaders.register do |context|
        captured = context
        { "X-Test-Feature" => context.feature_name }
      end
      decision_model.update!(vision_enabled: true)
      request =
        stub_request(:post, decision_model.url).with(
          headers: {
            "X-Test-Feature" => "workflow",
            "Authorization" => "Bearer #{decision_model.api_key}",
          },
        ).to_return(body: response_body.to_json)

      client.decide(
        "Hello",
        questions:,
        images: ["data:image/png;base64,AAAA"],
        feature_name: "workflow",
      )

      expect(request).to have_been_requested.once
      expect(captured).to have_attributes(model: decision_model, has_images: true, streaming: false)
    end

    it "does not send registered or validation-bypassing custom headers to OpenAI" do
      DiscourseAi::RequestHeaders.register { |_context| { "X-Test-Feature" => "x" } }
      decision_model.update!(provider: "open_ai", url: "https://api.openai.com/v1/decisions")
      decision_model.update_columns(custom_headers: [{ name: "X-Custom-Key", value: "secret" }])
      request =
        stub_request(:post, decision_model.url)
          .with { |req| (req.headers.keys & %w[X-Test-Feature X-Custom-Key]).empty? }
          .to_return(status: 400, body: "{}")

      expect { client.decide("Hello", questions:, feature_name: "workflow") }.to raise_error(
        DiscourseAi::Decisions::RequestFailed,
      )
      expect(request).to have_been_requested.once
    end
  end
end
