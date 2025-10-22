# frozen_string_literal: true

RSpec.describe DiscourseAi::Configuration::EmbeddingDefsValidator do
  before { enable_current_plugin }

  describe "#valid_value?" do
    fab!(:embedding_definition)
    let(:validator) { described_class.new({ run_check_in_tests: true }) }

    context "when resetting the value back to blank" do
      before do
        WebMock.stub_request(:post, embedding_definition.url).to_return(
          status: 200,
          body: [[1]].to_json,
        )

        SiteSetting.ai_embeddings_selected_model = embedding_definition.id
      end

      context "with embeddings enabled" do
        before { SiteSetting.ai_embeddings_enabled = true }

        it "returns false" do
          expect(validator.valid_value?("")).to eq(false)
          expect(validator.error_message).to eq(
            I18n.t("discourse_ai.embeddings.configuration.disable_embeddings"),
          )
        end
      end

      context "with embeddings disabled" do
        it "returns true" do
          expect(validator.valid_value?("")).to eq(true)
        end
      end
    end

    context "when selecting a model" do
      it "returns false if the test fails" do
        WebMock.stub_request(:post, embedding_definition.url).to_return(status: 404)

        expect(validator.valid_value?(embedding_definition.id)).to eq(false)
        expect(validator.error_message).to eq(
          I18n.t("discourse_ai.embeddings.configuration.model_test_failed"),
        )
      end

      it "returns true if test works" do
        WebMock.stub_request(:post, embedding_definition.url).to_return(
          status: 200,
          body: [[1]].to_json,
        )

        expect(validator.valid_value?(embedding_definition.id)).to eq(true)
      end
    end
  end
end
