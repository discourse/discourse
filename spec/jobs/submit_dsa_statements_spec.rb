# frozen_string_literal: true
RSpec.describe Jobs::SubmitDsaStatements do
  before do
    SiteSetting.dsa_reporting_enabled = true
    SiteSetting.dsa_api_token = "test-token"
  end

  let(:endpoint) { "https://sandbox.sor.dsa.ec.europa.eu/api/v1/statements" }

  describe "#execute" do
    it "submits complete statements together and leaves unfinished classification pending" do
      statements = Fabricate.times(100, :dsa_statement_of_reason)
      overflow = Fabricate(:dsa_statement_of_reason)
      incomplete = Fabricate(:dsa_statement_of_reason, classified_at: nil)
      response_statements =
        statements.map { |statement| { puid: statement.puid, uuid: SecureRandom.uuid } }
      request =
        stub_request(:post, endpoint).with(
          headers: {
            "Authorization" => "Bearer test-token",
          },
          body: {
            statements: statements.map(&:payload),
          },
        ).to_return(status: 201, body: { statements: response_statements.reverse }.to_json)

      described_class.new.execute({})

      expect(request).to have_been_requested.once
      expect(statements.map { |statement| statement.reload.submission_uuid }).to eq(
        response_statements.map { |statement| statement[:uuid] },
      )
      expect(incomplete.reload).to be_pending
      expect(incomplete.attempts).to eq(0)
      expect(overflow.reload.attempts).to eq(0)
    end

    it "reconciles an accepted statement after a timeout without sending it twice" do
      freeze_time
      statement = Fabricate(:dsa_statement_of_reason)
      creation = stub_request(:post, endpoint).to_timeout
      described_class.new.execute({})
      expect(statement.reload).to be_pending
      expect(statement.next_attempt_at).to be > Time.zone.now
      SiteSetting.dsa_api_environment = "production"
      existing =
        stub_request(
          :get,
          "https://sandbox.sor.dsa.ec.europa.eu/api/v1/statement/existing-puid/#{statement.puid}",
        ).to_return(
          status: 302,
          body: { puid: statement.puid, message: "statement of reason found" }.to_json,
        )
      freeze_time statement.next_attempt_at

      described_class.new.execute({})

      expect(statement.reload).to be_submitted
      expect(creation).to have_been_requested.once
      expect(existing).to have_been_requested.once
    end

    it "keeps a rejected row visible without blocking valid rows in the same batch" do
      freeze_time
      rejected, valid = Fabricate.times(2, :dsa_statement_of_reason)
      stub_request(:post, endpoint).to_return(
        status: 422,
        body: { errors: { statement_0: { category: ["Invalid category"] } } }.to_json,
      )

      described_class.new.execute({})

      expect(rejected.reload).to be_failed
      expect(rejected.error_code).to eq("validation")
      expect(valid.reload).to be_pending
      freeze_time valid.next_attempt_at
      stub_request(
        :get,
        "https://sandbox.sor.dsa.ec.europa.eu/api/v1/statement/existing-puid/#{valid.puid}",
      ).to_return(status: 404, body: { puid: valid.puid }.to_json)
      stub_request(:post, endpoint).with(body: { statements: [valid.payload] }).to_return(
        status: 201,
        body: { statements: [{ puid: valid.puid, uuid: SecureRandom.uuid }] }.to_json,
      )
      described_class.new.execute({})
      expect(valid.reload).to be_submitted
    end

    it "obeys rate limiting and exposes credential failures for administrator recovery" do
      freeze_time
      statement = Fabricate(:dsa_statement_of_reason)
      stub_request(:post, endpoint).to_return(
        status: 429,
        headers: {
          "Retry-After" => "900",
        },
        body: "{}",
      )
      described_class.new.execute({})
      expect(statement.reload.next_attempt_at).to be_within_one_second_of(15.minutes.from_now)
      freeze_time statement.next_attempt_at
      stub_request(
        :get,
        "https://sandbox.sor.dsa.ec.europa.eu/api/v1/statement/existing-puid/#{statement.puid}",
      ).to_return(status: 401, body: "{}")

      described_class.new.execute({})

      expect(statement.reload).to be_failed
      expect(statement.error_code).to eq("authentication")
      statement.retry!
      expect(statement.reload).to be_pending
    end

    it "does not contact the API while reporting is disabled or content metadata is missing" do
      statement = Fabricate(:dsa_statement_of_reason, payload: {})
      SiteSetting.dsa_reporting_enabled = false
      described_class.new.execute({})
      expect(statement.reload.attempts).to eq(0)
      SiteSetting.dsa_reporting_enabled = true

      described_class.new.execute({})

      expect(statement.reload).to be_failed
      expect(statement.error_code).to eq("metadata")
      expect(WebMock).not_to have_requested(:post, endpoint)
    end
  end
end
