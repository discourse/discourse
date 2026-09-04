# frozen_string_literal: true

load File.expand_path("../../script/notify_patch_triage_of_flaky_tests", __dir__)

RSpec.describe NotifyPatchTriageOfFlakyTests do
  subject(:notify_patch_triage) { described_class.call(environment:) }

  let(:endpoint) { "https://patch.example.com/patch-triage/github/flaky-test-report" }
  let(:signing_secret) { "test-secret" }
  let(:environment) do
    {
      "PATCH_TRIAGE_FLAKY_TEST_REPORT_URL" => endpoint,
      "PATCH_TRIAGE_FLAKY_TEST_REPORT_SECRET" => signing_secret,
      "GITHUB_REPOSITORY" => "discourse/discourse",
      "GITHUB_RUN_ID" => "123",
      "GITHUB_RUN_ATTEMPT" => "2",
      "REPORT_ARTIFACT_ID" => "456",
      "SCREENSHOT_ARTIFACT_ID" => "789",
    }
  end
  let(:payload) do
    JSON.generate(
      repository: "discourse/discourse",
      workflow_run_id: 123,
      run_attempt: 2,
      report_artifact_id: 456,
      screenshot_artifact_id: 789,
    )
  end
  let(:signature) { OpenSSL::HMAC.hexdigest("SHA256", signing_secret, payload) }

  before { stub_request(:post, endpoint).to_return(status: 202) }

  it "sends the signed workflow and artifact identifiers" do
    notify_patch_triage

    expect(
      a_request(:post, endpoint).with(
        body: payload,
        headers: {
          "Content-Type" => "application/json",
          "X-Hub-Signature-256" => "sha256=#{signature}",
        },
      ),
    ).to have_been_made.once
  end

  it "omits the screenshot artifact when the workflow did not create one" do
    environment["SCREENSHOT_ARTIFACT_ID"] = ""

    notify_patch_triage

    expect(
      a_request(:post, endpoint).with do |request|
        !JSON.parse(request.body).key?("screenshot_artifact_id")
      end,
    ).to have_been_made.once
  end

  it "skips delivery when either delivery secret is missing" do
    environment.delete("PATCH_TRIAGE_FLAKY_TEST_REPORT_URL")

    expect { notify_patch_triage }.to output(
      "::warning::Patch Triage flaky-test delivery secrets are not configured; skipping notification\n",
    ).to_stderr
    expect(a_request(:post, endpoint)).not_to have_been_made
  end

  it "retries a failed delivery" do
    stub_request(:post, endpoint).to_return({ status: 503 }, { status: 202 })
    allow(described_class).to receive(:sleep)

    notify_patch_triage

    expect(a_request(:post, endpoint)).to have_been_made.twice
    expect(described_class).to have_received(:sleep).with(1)
  end
end
