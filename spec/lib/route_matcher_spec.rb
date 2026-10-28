# frozen_string_literal: true

RSpec.describe RouteMatcher do
  def request_env(path_parameters:, query_parameters: {}, request_method: "GET")
    ActionDispatch::TestRequest
      .create
      .tap do |request|
        request.path_parameters = path_parameters
        request.set_header(
          "action_dispatch.request.query_parameters",
          query_parameters.stringify_keys,
        )
        request.request_method = request_method
      end
      .env
  end

  describe "#match?" do
    it "preserves merged request semantics for ordinary parameters" do
      matcher =
        described_class.new(params: %i[status], allowed_param_values: { "status" => ["open"] })
      env = request_env(path_parameters: {}, query_parameters: { status: "open" })

      expect(matcher.match?(env: env)).to eq(true)
    end

    it "matches only recognized values for path parameters" do
      matcher =
        described_class.new(
          path_params: %i[topic_id],
          allowed_param_values: {
            "topic_id" => %w[3 4],
          },
        )

      expect(matcher.match?(env: request_env(path_parameters: { topic_id: "3" }))).to eq(true)
      expect(matcher.match?(env: request_env(path_parameters: { topic_id: "5" }))).to eq(false)
      expect(
        matcher.match?(env: request_env(path_parameters: {}, query_parameters: { topic_id: "3" })),
      ).to eq(false)
    end

    it "does not let query parameters override a recognized path value" do
      matcher =
        described_class.new(
          path_params: %i[topic_id],
          allowed_param_values: {
            "topic_id" => ["3"],
          },
        )
      env = request_env(path_parameters: { topic_id: "4" }, query_parameters: { topic_id: "3" })

      expect(matcher.match?(env: env)).to eq(false)
    end

    it "uses aliases only when they are recognized path parameters" do
      matcher =
        described_class.new(
          path_params: %i[topic_id],
          aliases: {
            topic_id: :id,
          },
          allowed_param_values: {
            "topic_id" => ["3"],
          },
        )

      expect(matcher.match?(env: request_env(path_parameters: { id: "3" }))).to eq(true)
      expect(
        matcher.match?(env: request_env(path_parameters: {}, query_parameters: { id: "3" })),
      ).to eq(false)
    end

    it "treats nil canonical values as absent when an alias is recognized" do
      matcher =
        described_class.new(
          path_params: %w[topic_id],
          aliases: {
            "topic_id" => :id,
          },
          allowed_param_values: {
            "topic_id" => ["3"],
          },
        )
      env = request_env(path_parameters: { "topic_id" => nil, :id => "3" })

      expect(matcher.match?(env: env)).to eq(true)
    end

    it "rejects ambiguous recognized aliases" do
      matcher =
        described_class.new(
          path_params: %i[topic_id],
          aliases: {
            topic_id: :id,
          },
          allowed_param_values: {
            "topic_id" => ["3"],
          },
        )
      env = request_env(path_parameters: { topic_id: "3", id: "3" })

      expect(matcher.match?(env: env)).to eq(false)
    end

    it "requires every configured path restriction" do
      matcher =
        described_class.new(
          path_params: %i[topic_id external_id],
          allowed_param_values: {
            "topic_id" => ["3"],
            "external_id" => ["external-3"],
          },
        )

      expect(matcher.match?(env: request_env(path_parameters: { topic_id: "3" }))).to eq(false)
    end

    it "keeps blank path allowlists unrestricted" do
      matcher =
        described_class.new(
          path_params: %i[topic_id external_id],
          allowed_param_values: {
            "topic_id" => ["3"],
            "external_id" => [],
          },
        )

      expect(matcher.match?(env: request_env(path_parameters: { topic_id: "3" }))).to eq(true)
    end

    it "requires ordinary and path restrictions together" do
      matcher =
        described_class.new(
          params: %i[status],
          path_params: %i[topic_id],
          allowed_param_values: {
            "status" => ["open"],
            "topic_id" => ["3"],
          },
        )

      expect(
        matcher.match?(
          env:
            request_env(path_parameters: { topic_id: "3" }, query_parameters: { status: "closed" }),
        ),
      ).to eq(false)
    end

    it "gives path semantics precedence for overlapping declarations" do
      matcher =
        described_class.new(
          params: %w[topic_id],
          path_params: %i[topic_id],
          allowed_param_values: {
            "topic_id" => ["3"],
          },
        )
      env = request_env(path_parameters: { topic_id: "4" }, query_parameters: { topic_id: "3" })

      expect(matcher.match?(env: env)).to eq(false)
    end

    it "matches exact scalar types and rejects structured path values" do
      matcher = described_class.new(path_params: %i[id], allowed_param_values: { "id" => [3, "4"] })

      expect(matcher.match?(env: request_env(path_parameters: { id: 3 }))).to eq(true)
      expect(matcher.match?(env: request_env(path_parameters: { id: "3" }))).to eq(false)
      expect(matcher.match?(env: request_env(path_parameters: { id: [3] }))).to eq(false)
      expect(matcher.match?(env: request_env(path_parameters: { id: { value: 3 } }))).to eq(false)
    end

    it "preserves path parameters when allowed values are replaced" do
      matcher = described_class.new(path_params: %i[id])

      replacement = matcher.with_allowed_param_values("id" => ["3"])

      expect(replacement.path_params).to eq([:id])
      expect(replacement.match?(env: request_env(path_parameters: { id: "3" }))).to eq(true)
    end

    it "recognizes and caches routes before controller dispatch" do
      request = ActionDispatch::TestRequest.create
      request.set_header("PATH_INFO", "/t/3.json")
      request.request_method = "GET"
      matcher =
        described_class.new(
          actions: %w[topics#show],
          path_params: %i[topic_id],
          aliases: {
            topic_id: :id,
          },
          allowed_param_values: {
            "topic_id" => ["3"],
          },
        )

      expect(matcher.match?(env: request.env)).to eq(true)
      expect(request.env[described_class::PATH_PARAMETERS]).to include(
        controller: "topics",
        action: "show",
        id: "3",
      )
    end

    it "recognizes routes after ordinary parameters are loaded when actions are unrestricted" do
      request = ActionDispatch::TestRequest.create
      request.set_header("PATH_INFO", "/t/3.json")
      request.set_header("action_dispatch.request.query_parameters", { "status" => "open" })
      request.request_method = "GET"
      matcher =
        described_class.new(
          params: %i[status],
          path_params: %i[topic_id],
          aliases: {
            topic_id: :id,
          },
          allowed_param_values: {
            "status" => ["open"],
            "topic_id" => ["3"],
          },
        )

      expect(matcher.match?(env: request.env)).to eq(true)
      expect(request.env[described_class::PATH_PARAMETERS]).to include(id: "3")
    end

    it "handles a missing ordinary category alias value" do
      matcher =
        described_class.new(
          params: %i[category_id],
          aliases: {
            category_id: :category_slug_path_with_id,
          },
          allowed_param_values: {
            "category_id" => ["3"],
          },
        )

      expect(matcher.match?(env: request_env(path_parameters: {}))).to eq(false)
    end
  end
end
