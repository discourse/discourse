# frozen_string_literal: true

RSpec.describe DiscourseAi::AiHelper::Painter do
  subject(:painter) { described_class.new }

  fab!(:user)

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_stability_api_url = "https://api.stability.dev"
    SiteSetting.ai_stability_api_key = "abc"
    SiteSetting.ai_openai_api_key = "abc"
  end

  describe "#commission_thumbnails" do
    context "when illustrate post model is stable_diffusion_xl" do
      before { SiteSetting.ai_helper_illustrate_post_model = "stable_diffusion_xl" }

      let(:artifacts) do
        %w[
          iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==
          iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mP8z8BQz0AEYBxVSF+FABJADveWkH6oAAAAAElFTkSuQmCC
          iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mNk+M9Qz0AEYBxVSF+FAAhKDveksOjmAAAAAElFTkSuQmCC
          iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mNkYPhfz0AEYBxVSF+FAP5FDvcfRYWgAAAAAElFTkSuQmCC
        ]
      end

      let(:raw_content) do
        "Poetry is a form of artistic expression that uses language aesthetically and rhythmically to evoke emotions and ideas."
      end

      let(:expected_image_prompt) { <<~TEXT.strip }
          Visualize a vibrant scene of an inkwell bursting, spreading colors across a blank canvas,
          embodying words in tangible forms, symbolizing the rhythm and emotion evoked by poetry,
          under the soft glow of a full moon.
          TEXT

      it "returns 4 samples" do
        StableDiffusionStubs.new.stub_response(expected_image_prompt, artifacts)

        thumbnails =
          DiscourseAi::Completions::Llm.with_prepared_responses([expected_image_prompt]) do
            thumbnails = painter.commission_thumbnails(raw_content, user)
          end

        thumbnail_urls = Upload.last(4).map(&:short_url)

        expect(
          thumbnails.map { |upload_serializer| upload_serializer.short_url },
        ).to contain_exactly(*thumbnail_urls)
      end
    end

    context "when illustrate post model is dall_e_3" do
      before { SiteSetting.ai_helper_illustrate_post_model = "dall_e_3" }

      let(:artifacts) do
        %w[
          iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==
        ]
      end

      let(:raw_content) do
        "Poetry is a form of artistic expression that uses language aesthetically and rhythmically to evoke emotions and ideas."
      end

      it "returns an image sample" do
        _post = Fabricate(:post)

        data = [{ b64_json: artifacts.first, revised_prompt: "colors on a canvas" }]
        WebMock
          .stub_request(:post, "https://api.openai.com/v1/images/generations")
          .with do |request|
            _json = JSON.parse(request.body, symbolize_names: true)
            true
          end
          .to_return(status: 200, body: { data: data }.to_json)

        thumbnails = painter.commission_thumbnails(raw_content, user)
        thumbnail_urls = Upload.last(1).map(&:short_url)

        expect(
          thumbnails.map { |upload_serializer| upload_serializer.short_url },
        ).to contain_exactly(*thumbnail_urls)
      end
    end
  end
end
