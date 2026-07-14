# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::HttpRequest::ResponseParser do
  def build_response(status:, body:, headers: {})
    instance_double(Faraday::Response, status: status, body: body, headers: headers)
  end

  describe ".parse" do
    it "parses a JSON response" do
      response =
        build_response(
          status: 200,
          body: '{"result":"ok"}',
          headers: {
            "content-type" => "application/json",
          },
        )
      result = described_class.parse(response)

      expect(result[:status]).to eq(200)
      expect(result[:body]).to eq("result" => "ok")
      expect(result[:headers]).to include("content-type" => "application/json")
    end

    it "wraps non-JSON responses in a data key" do
      response =
        build_response(
          status: 200,
          body: "<html>hello</html>",
          headers: {
            "content-type" => "text/html",
          },
        )
      result = described_class.parse(response)

      expect(result[:body]).to eq("data" => "<html>hello</html>")
    end

    it "handles missing content-type as non-JSON" do
      response = build_response(status: 200, body: "plain text", headers: {})
      result = described_class.parse(response)

      expect(result[:body]).to eq("data" => "plain text")
    end

    it "handles invalid JSON gracefully" do
      response =
        build_response(
          status: 200,
          body: "not json{",
          headers: {
            "content-type" => "application/json",
          },
        )
      result = described_class.parse(response)

      expect(result[:body]).to eq("data" => "not json{")
    end

    it "truncates responses exceeding size limit" do
      large_body = "x" * (described_class::MAX_RESPONSE_BODY_SIZE + 100)
      response =
        build_response(status: 200, body: large_body, headers: { "content-type" => "text/plain" })
      result = described_class.parse(response)

      expect(result[:body]["data"].bytesize).to eq(described_class::MAX_RESPONSE_BODY_SIZE)
    end

    it "emits a warning log when truncation occurs" do
      large_body = "x" * (described_class::MAX_RESPONSE_BODY_SIZE + 100)
      response =
        build_response(status: 200, body: large_body, headers: { "content-type" => "text/plain" })
      log = instance_spy(DiscourseWorkflows::Executor::StepLog)

      described_class.parse(response, log: log)

      expect(log).to have_received(:warn).with(a_string_including("truncated"))
    end

    it "respects a custom max_response_size_kb" do
      response =
        build_response(status: 200, body: "x" * 3000, headers: { "content-type" => "text/plain" })
      log = instance_spy(DiscourseWorkflows::Executor::StepLog)

      result = described_class.parse(response, max_size_kb: 2, log: log)

      expect(log).to have_received(:warn).with(a_string_including("truncated"))
      expect(result[:body]["data"].bytesize).to eq(2.kilobytes)
    end

    it "clamps max_response_size_kb to a minimum of 1 KB" do
      response =
        build_response(status: 200, body: "x" * 2048, headers: { "content-type" => "text/plain" })
      log = instance_spy(DiscourseWorkflows::Executor::StepLog)

      result = described_class.parse(response, max_size_kb: 0, log: log)

      expect(result[:body]["data"].bytesize).to eq(1.kilobyte)
    end

    it "clamps max_response_size_kb to the hard cap" do
      response =
        build_response(
          status: 200,
          body: "x" * (described_class::MAX_ALLOWED_SIZE + 100),
          headers: {
            "content-type" => "text/plain",
          },
        )
      log = instance_spy(DiscourseWorkflows::Executor::StepLog)

      result = described_class.parse(response, max_size_kb: 999_999, log: log)

      expect(log).to have_received(:warn).with(a_string_including("truncated"))
      expect(result[:body]["data"].bytesize).to eq(described_class::MAX_ALLOWED_SIZE)
    end
  end
end
