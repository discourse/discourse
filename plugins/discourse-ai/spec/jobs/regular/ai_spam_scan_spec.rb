# frozen_string_literal: true

require "aws-sdk-bedrockruntime"

RSpec.describe Jobs::AiSpamScan do
  subject(:job) { described_class.new }

  fab!(:user) do
    Fabricate(:user, trust_level: TrustLevel[0], ip_address: nil, registration_ip_address: nil)
  end
  fab!(:post) { Fabricate(:post, user:) }
  fab!(:llm_model)
  fab!(:spam_setting) { AiModerationSetting.create!(setting_type: :spam, llm_model:) }

  before do
    enable_current_plugin
    SiteSetting.ai_spam_detection_enabled = true
  end

  def run_failed_scan
    logster_logger = mock("Logster logger")
    logster_logger.expects(:add_with_opts).never
    Logster.stubs(:logger).returns(logster_logger)

    logger =
      track_log_messages do
        expect { job.perform(post_id: post.id) }.to raise_error(
          Jobs::HandledExceptionWrapper,
        ) do |error|
          SidekiqLogsterReporter.new.call(error, { job: { "class" => described_class.name } })
        end
      end

    expect(logger.warnings).to be_empty
    expect(logger.errors).to be_empty
    expect(AdminNotice.where(identifier: "ai_spam_scan_errors")).to exist
    expect(AiSpamLog.where(post:)).not_to exist
  end

  it "reports provider failures immediately without an API audit record" do
    expect(ProblemCheck[:ai_spam_scan_errors]).to be_inline
    failure = DiscourseAi::Completions::Endpoints::Base::CompletionFailed.new("Invalid API key")

    DiscourseAi::Completions::Llm.with_prepared_responses([failure]) { run_failed_scan }

    expect(AiApiAuditLog.count).to eq(0)
  end

  it "clears the notice immediately when a spam scan succeeds" do
    ProblemCheckTracker[:ai_spam_scan_errors].problem!
    expect(AdminNotice.where(identifier: "ai_spam_scan_errors")).to exist

    DiscourseAi::Completions::Llm.with_prepared_responses([{ spam: false }]) do
      job.execute(post_id: post.id)
    end

    expect(AdminNotice.where(identifier: "ai_spam_scan_errors")).not_to exist
  end

  it "keeps the notice when a decision model succeeds without using the LLM" do
    decision_model = Fabricate(:decision_model)
    spam_setting.update!(decision_model:)
    ProblemCheckTracker[:ai_spam_scan_errors].problem!

    DiscourseAi::Decisions.with_canned_answers(spam: 0.01) { job.execute(post_id: post.id) }

    expect(AiSpamLog.find_by!(post:).decision_model_id).to eq(decision_model.id)
    expect(AdminNotice.where(identifier: "ai_spam_scan_errors")).to exist
  end

  it "retries insufficient-credit failures with an admin notice instead of Logster errors" do
    model = Fabricate(:anthropic_model)
    spam_setting.update!(llm_model: model)
    stub_request(:post, model.url).to_return(
      status: 400,
      body: { error: { message: "Your credit balance is too low" } }.to_json,
    )

    2.times { run_failed_scan }

    expect(AdminNotice.where(identifier: "ai_spam_scan_errors").count).to eq(1)
  end

  it "retries invalid-key failures with an admin notice instead of Logster errors" do
    stub_request(:post, llm_model.url).to_return(
      status: 401,
      body: { error: { message: "Invalid API key" } }.to_json,
    )

    run_failed_scan
  end

  it "retries temporary provider failures without logging each attempt" do
    DiscourseAi::Completions::Endpoints::Base.any_instance.stubs(:sleep_before_retry)
    request = stub_request(:post, llm_model.url).to_return(status: 503, body: "Unavailable")

    run_failed_scan

    expect(request).to have_been_requested.times(3)
  end

  it "retries rate-limited provider requests without logging each attempt" do
    DiscourseAi::Completions::Endpoints::Base.any_instance.stubs(:sleep_before_retry)
    request = stub_request(:post, llm_model.url).to_return(status: 429, body: "Rate limited")

    run_failed_scan

    expect(request).to have_been_requested.times(4)
  end

  it "retries network failures without logging each attempt" do
    DiscourseAi::Completions::Endpoints::Base.any_instance.stubs(:sleep_before_retry)
    stub_request(:post, llm_model.url).to_raise(Net::ReadTimeout)

    run_failed_scan
  end

  it "retries SDK provider failures with an admin notice instead of Logster errors" do
    model = Fabricate(:bedrock_converse_model)
    spam_setting.update!(llm_model: model)
    client = mock("Bedrock client")
    context = Seahorse::Client::RequestContext.new
    context.http_response.status_code = 403
    client.stubs(:converse_stream).raises(
      Aws::BedrockRuntime::Errors::AccessDeniedException.new(context, "Invalid credentials"),
    )
    Aws::BedrockRuntime::Client.stubs(:new).returns(client)

    run_failed_scan
  end

  it "reports SDK failures without an HTTP status through the admin notice" do
    model = Fabricate(:bedrock_converse_model)
    spam_setting.update!(llm_model: model)
    client = mock("Bedrock client")
    client.stubs(:converse_stream).raises(
      Aws::BedrockRuntime::Errors::ServiceError.new(nil, "Unknown SDK failure"),
    )
    Aws::BedrockRuntime::Client.stubs(:new).returns(client)

    run_failed_scan
  end

  it "reports stream failures even when the provider returned HTTP 200" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:read_body) do |&block|
      content = { spam: false, reason: "A genuine post" }.to_json
      block.call("data: #{{ choices: [{ delta: { content: content } }] }.to_json}\n\n")
      raise EOFError, "Connection closed during streaming"
    end
    http = mock("HTTP connection")
    http.stubs(:request).yields(response)
    FinalDestination::HTTP.stubs(:start).yields(http)
    DiscourseAi::Completions::Endpoints::Base.any_instance.stubs(:sleep_before_retry)

    run_failed_scan

    expect(AiApiAuditLog.last.response_status).to eq(200)
  end

  it "still logs unexpected scanner failures" do
    error = StandardError.new("Unexpected scanner failure")
    logger =
      track_log_messages do
        DiscourseAi::Completions::Llm.with_prepared_responses([error]) do
          expect { job.execute(post_id: post.id) }.to raise_error(error)
        end
      end

    expect(logger.warnings.join).to include("Error in SpamScanner", error.message)
  end
end
