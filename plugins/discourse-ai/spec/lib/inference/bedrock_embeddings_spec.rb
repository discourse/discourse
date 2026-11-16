# frozen_string_literal: true

RSpec.describe DiscourseAi::Inference::BedrockEmbeddings do
  subject(:client) do
    described_class.new(
      region: "us-east-1",
      model_id: model_id,
      dimensions: dimensions,
      api_key: api_key,
      access_key_id: access_key_id,
      role_arn: role_arn,
    )
  end

  let(:model_id) { "cohere.embed-v4:0" }
  let(:dimensions) { nil }
  let(:api_key) { "bedrock-api-key" }
  let(:access_key_id) { nil }
  let(:role_arn) { nil }
  let(:invoke_url) { "https://bedrock-runtime.us-east-1.amazonaws.com/model/#{model_id}/invoke" }

  before { enable_current_plugin }

  after { described_class.reset_role_credentials! }

  def stub_invoke(body: { embeddings: { float: [[0.1, 0.2, 0.3]] } }, status: 200, headers: {})
    stub_request(:post, invoke_url).to_return(
      status: status,
      body: body.to_json,
      headers: { "Content-Type" => "application/json" }.merge(headers),
    )
  end

  describe "#perform!" do
    it "requests a Cohere document embedding and returns the float vector" do
      stub_invoke

      expect(client.perform!("hello world")).to eq([0.1, 0.2, 0.3])
      expect(WebMock).to have_requested(:post, invoke_url).with(
        body: {
          texts: ["hello world"],
          input_type: "search_document",
          embedding_types: ["float"],
          truncate: "END",
        },
      )
    end

    context "with dimensions on a Cohere model" do
      let(:dimensions) { 512 }

      it "requests that output dimension" do
        stub_invoke

        client.perform!("hello world")

        expect(WebMock).to have_requested(:post, invoke_url).with(
          body: hash_including(output_dimension: 512),
        )
      end
    end

    context "with a Titan text model" do
      let(:model_id) { "amazon.titan-embed-text-v2:0" }
      let(:dimensions) { 256 }

      it "sends the Titan payload and returns its embedding" do
        stub_invoke(body: { embedding: [0.4, 0.5] })

        expect(client.perform!("hello world")).to eq([0.4, 0.5])
        expect(WebMock).to have_requested(:post, invoke_url).with(
          body: {
            inputText: "hello world",
            normalize: true,
            dimensions: 256,
          },
        )
      end
    end

    context "with a model family it can't build a payload for" do
      let(:model_id) { "amazon.nova-2-multimodal-embeddings-v1:0" }

      it "raises an invalid configuration error without calling Bedrock" do
        stub_invoke

        expect { client.perform!("hello world") }.to raise_error(
          DiscourseAi::Inference::EmbeddingInferenceError,
        ) { |error| expect(error.category).to eq(:invalid_configuration) }
        expect(WebMock).not_to have_requested(:post, invoke_url)
      end
    end

    it "sends a Bedrock API key as a bearer token" do
      stub_invoke

      client.perform!("hello world")

      expect(WebMock).to have_requested(:post, invoke_url).with(
        headers: {
          "Authorization" => "Bearer bedrock-api-key",
        },
      )
    end

    context "with an access key ID" do
      let(:access_key_id) { "AKIAEXAMPLE" }
      let(:api_key) { "secret-access-key" }

      it "signs the request with that key pair" do
        stub_invoke

        client.perform!("hello world")

        expect(WebMock).to have_requested(:post, invoke_url).with { |request|
          request.headers["Authorization"].start_with?(
            "AWS4-HMAC-SHA256 Credential=AKIAEXAMPLE/",
          ) && request.headers["Authorization"].include?("/us-east-1/bedrock/aws4_request")
        }
      end
    end

    context "with a role ARN" do
      let(:role_arn) { "arn:aws:iam::123456789012:role/bedrock" }
      let(:api_key) { nil }

      it "signs the request with the assumed role's temporary credentials" do
        allow(Aws::STS::Client).to receive(:new).and_return(instance_double(Aws::STS::Client))
        allow(Aws::AssumeRoleCredentials).to receive(:new).and_return(
          Aws::Credentials.new("ASIAROLE", "role-secret", "role-session-token"),
        )
        stub_invoke

        client.perform!("hello world")

        expect(WebMock).to have_requested(:post, invoke_url).with { |request|
          request.headers["Authorization"].start_with?("AWS4-HMAC-SHA256 Credential=ASIAROLE/") &&
            request.headers["X-Amz-Security-Token"] == "role-session-token"
        }
      end
    end

    context "with a role ARN that can't be assumed" do
      let(:role_arn) { "arn:aws:iam::123456789012:role/bedrock" }
      let(:api_key) { nil }

      around do |example|
        previous = ENV.to_h.slice("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY")
        ENV["AWS_ACCESS_KEY_ID"] = "AKIAFROMENV"
        ENV["AWS_SECRET_ACCESS_KEY"] = "env-secret"
        example.run
      ensure
        %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY].each { |name| ENV[name] = previous[name] }
      end

      it "raises a terminal authorization error" do
        stub_request(:post, "https://sts.us-east-1.amazonaws.com/").to_return(
          status: 403,
          body: <<~XML,
            <ErrorResponse xmlns="https://sts.amazonaws.com/doc/2011-06-15/">
              <Error>
                <Type>Sender</Type>
                <Code>AccessDenied</Code>
                <Message>User is not authorized to perform: sts:AssumeRole</Message>
              </Error>
            </ErrorResponse>
          XML
          headers: {
            "Content-Type" => "text/xml",
          },
        )
        stub_invoke

        expect { client.perform!("hello world") }.to raise_error(
          DiscourseAi::Inference::EmbeddingInferenceError,
        ) { |error|
          expect([error.category, error.http_status, error.terminal?]).to eq(
            [:authorization_failed, 403, true],
          )
        }
        expect(WebMock).not_to have_requested(:post, invoke_url)
      end
    end

    context "without configured credentials" do
      let(:api_key) { nil }

      around do |example|
        previous = ENV.to_h.slice("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY")
        ENV["AWS_ACCESS_KEY_ID"] = "AKIAFROMENV"
        ENV["AWS_SECRET_ACCESS_KEY"] = "env-secret"
        example.run
      ensure
        %w[AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY].each { |name| ENV[name] = previous[name] }
      end

      it "signs the request with the AWS SDK's default credentials" do
        stub_invoke

        client.perform!("hello world")

        expect(WebMock).to have_requested(:post, invoke_url).with { |request|
          request.headers["Authorization"].start_with?("AWS4-HMAC-SHA256 Credential=AKIAFROMENV/")
        }
      end
    end

    it "raises a terminal authorization error when access is denied" do
      stub_invoke(
        status: 403,
        body: {
          message: "You don't have access to the model",
        },
        headers: {
          "x-amzn-ErrorType" => "AccessDeniedException",
        },
      )

      expect { client.perform!("hello world") }.to raise_error(
        DiscourseAi::Inference::EmbeddingInferenceError,
      ) { |error|
        expect([error.category, error.http_status, error.terminal?]).to eq(
          [:authorization_failed, 403, true],
        )
      }
    end

    it "raises a non-terminal error when Bedrock rejects one input" do
      stub_invoke(
        status: 400,
        body: {
          message: "Malformed input request",
        },
        headers: {
          "x-amzn-ErrorType" => "ValidationException",
        },
      )

      expect { client.perform!("hello world") }.to raise_error(
        DiscourseAi::Inference::EmbeddingInferenceError,
      ) { |error| expect([error.category, error.terminal?]).to eq([:request_rejected, false]) }
    end
  end
end
