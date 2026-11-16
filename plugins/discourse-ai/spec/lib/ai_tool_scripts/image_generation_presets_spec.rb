# frozen_string_literal: true

require "rails_helper"

RSpec.describe AiTool, ".image_generation_presets" do
  fab!(:bot_user) { Discourse.system_user }
  fab!(:ai_secret)

  let(:preset) do
    AiTool.image_generation_presets.find { |candidate| candidate[:preset_id] == preset_id }
  end
  let(:tool) do
    AiTool
      .create!(
        preset.slice(
          :name,
          :tool_name,
          :description,
          :parameters,
          :secret_contracts,
          :script,
          :summary,
        ).merge(created_by: bot_user),
      )
      .tap do |ai_tool|
        ai_tool.secret_bindings.create!(
          alias: preset[:secret_contracts].first[:alias],
          ai_secret: ai_secret,
        )
      end
  end
  let(:prompt) { "A lighthouse at sunset" }
  let(:png_data) { Base64.strict_encode64(File.binread(file_from_fixtures("logo.png"))) }
  let(:jpeg_data) { Base64.strict_encode64(File.binread(plugin_file_from_fixtures("1x1.jpg"))) }
  let(:source_image) do
    UploadCreator.new(file_from_fixtures("smallest.png"), "source.png").create_for(bot_user.id)
  end
  let(:source_data) { Base64.strict_encode64(File.binread(Discourse.store.path_for(source_image))) }
  let(:source_jpeg) do
    UploadCreator.new(plugin_file_from_fixtures("1x1.jpg"), "source.jpeg").create_for(bot_user.id)
  end
  let(:source_jpeg_data) do
    Base64.strict_encode64(File.binread(Discourse.store.path_for(source_jpeg)))
  end

  before { enable_current_plugin }

  def runner_for(parameters)
    tool.runner(parameters, llm: nil, bot_user: bot_user)
  end

  def expect_image_output(runner, result, filename, extension: "png")
    image = Upload.find_by(sha1: Upload.sha1_from_short_url(result.fetch("url")))

    expect(image).to be_present
    expect(image.original_filename).to eq(filename)
    expect(image.extension).to eq(extension)
    expect(image.user_id).to eq(bot_user.id)
    expect(runner.custom_raw).to eq("\n![#{prompt}](#{image.short_url})\n")
    expect(result).to eq("url" => image.short_url)
  end

  shared_examples "an OpenAI image preset" do |model|
    let(:headers) do
      { "Authorization" => "Bearer #{ai_secret.secret}", "Content-Type" => "application/json" }
    end
    let(:response_body) { { data: [{ b64_json: png_data }] }.to_json }

    it "generates images with the preset model and default or explicit size and quality" do
      [{}, { "size" => "1536x1024", "quality" => "high" }].each do |options|
        request =
          stub_request(:post, "https://api.openai.com/v1/images/generations").with(
            headers: headers,
            body: {
              model: model,
              prompt: prompt,
              size: options.fetch("size", "1024x1024"),
              quality: options.fetch("quality", "auto"),
              n: 1,
            },
          ).to_return(status: 200, body: response_body)
        runner = runner_for({ "prompt" => prompt }.merge(options))

        result = runner.invoke

        expect(request).to have_been_requested.once
        expect_image_output(runner, result, "generated_image.png")
      end
    end

    it "edits uploaded images using JSON data URLs with detected MIME types and the preset model and options" do
      request =
        stub_request(:post, "https://api.openai.com/v1/images/edits").with(
          headers: headers,
          body: {
            model: model,
            prompt: prompt,
            size: "1024x1536",
            quality: "medium",
            n: 1,
            images: [
              { image_url: "data:image/png;base64,#{source_data}" },
              { image_url: "data:image/jpeg;base64,#{source_jpeg_data}" },
            ],
          },
        ).to_return(status: 200, body: response_body)
      runner =
        runner_for(
          "prompt" => prompt,
          "size" => "1024x1536",
          "quality" => "medium",
          "image_urls" => [source_image.short_url, source_jpeg.short_url],
        )

      result = runner.invoke

      expect(request).to have_been_requested.once
      expect_image_output(runner, result, "edited_image.png")
    end

    it "returns API errors without creating an image for generation or editing" do
      { "generations" => [], "edits" => [source_image.short_url] }.each do |endpoint, images|
        stub_request(:post, "https://api.openai.com/v1/images/#{endpoint}").to_return(
          status: 400,
          body: { error: { message: "Unsupported image request" } }.to_json,
        )
        runner = runner_for("prompt" => prompt, "image_urls" => images)

        expect {
          expect(runner.invoke).to eq("error" => "OpenAI API Error: Unsupported image request")
        }.not_to change(Upload, :count)
        expect(runner.custom_raw).to be_nil
      end
    end

    it "reports responses missing image data or containing malformed JSON for generation or editing" do
      { "generations" => [], "edits" => [source_image.short_url] }.each do |endpoint, images|
        [[200, { data: [] }.to_json], [502, "<html>Bad Gateway</html>"]].each do |status, body|
          stub_request(:post, "https://api.openai.com/v1/images/#{endpoint}").to_return(
            status: status,
            body: body,
          )
          runner = runner_for("prompt" => prompt, "image_urls" => images)

          expect(runner.invoke).to eq(
            "error" => "Unexpected API response format",
            "status" => status,
            "body_preview" => body,
          )
          expect(runner.custom_raw).to be_nil
        end
      end
    end

    it "returns upload creation errors without setting custom_raw for generation or editing" do
      { "generations" => [], "edits" => [source_image.short_url] }.each do |endpoint, images|
        stub_request(:post, "https://api.openai.com/v1/images/#{endpoint}").to_return(
          status: 200,
          body: { data: [{ b64_json: Base64.strict_encode64("invalid image") }] }.to_json,
        )
        runner = runner_for("prompt" => prompt, "image_urls" => images)

        expect {
          result = runner.invoke
          expect(result["error"]).to start_with("Failed to create upload:")
        }.not_to change(Upload, :count)
        expect(runner.custom_raw).to be_nil
      end
    end
  end

  shared_examples "a Gemini image preset" do |model|
    let(:endpoint) do
      "https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent"
    end
    let(:headers) { { "x-goog-api-key" => ai_secret.secret, "Content-Type" => "application/json" } }

    it "generates PNG images with the preset model and optional aspect ratio" do
      [nil, "16:9"].each do |aspect_ratio|
        config = { responseModalities: ["Image"] }
        config[:imageConfig] = { aspectRatio: aspect_ratio } if aspect_ratio
        request =
          stub_request(:post, endpoint).with(
            headers: headers,
            body: {
              contents: [{ parts: [{ text: prompt }] }],
              generationConfig: config,
            },
          ).to_return(
            status: 200,
            body: {
              candidates: [
                { content: { parts: [{ inlineData: { mimeType: "image/png", data: png_data } }] } },
              ],
            }.to_json,
          )
        parameters = { "prompt" => prompt }
        parameters["aspect_ratio"] = aspect_ratio if aspect_ratio
        runner = runner_for(parameters)

        result = runner.invoke

        expect(request).to have_been_requested.once
        expect_image_output(runner, result, "generated_image.png")
      end
    end

    it "edits uploaded images with detected MIME types, the preset model, and aspect ratio and preserves JPEG output" do
      request =
        stub_request(:post, endpoint).with(
          headers: headers,
          body: {
            contents: [
              {
                parts: [
                  { inlineData: { mimeType: "image/png", data: source_data } },
                  { inlineData: { mimeType: "image/jpeg", data: source_jpeg_data } },
                  { text: prompt },
                ],
              },
            ],
            generationConfig: {
              responseModalities: ["Image"],
              imageConfig: {
                aspectRatio: "9:16",
              },
            },
          },
        ).to_return(
          status: 200,
          body: {
            candidates: [
              {
                content: {
                  parts: [
                    { text: "Here is the edited image" },
                    { inlineData: { mimeType: "image/jpeg", data: jpeg_data } },
                  ],
                },
              },
            ],
          }.to_json,
        )
      runner =
        runner_for(
          "prompt" => prompt,
          "aspect_ratio" => "9:16",
          "image_urls" => [source_image.short_url, source_jpeg.short_url],
        )

      result = runner.invoke

      expect(request).to have_been_requested.once
      # Identical image bytes reuse the source upload.
      expect_image_output(runner, result, source_jpeg.original_filename, extension: "jpeg")
    end

    it "returns API errors without creating an image" do
      stub_request(:post, endpoint).to_return(
        status: 400,
        body: { error: { message: "Unsupported image request" } }.to_json,
      )
      runner = runner_for("prompt" => prompt)

      expect {
        expect(runner.invoke).to eq("error" => "Gemini API Error: Unsupported image request")
      }.not_to change(Upload, :count)
      expect(runner.custom_raw).to be_nil
    end

    it "reports responses missing candidates or containing malformed JSON" do
      [[200, "{}"], [502, "<html>Bad Gateway</html>"]].each do |status, body|
        stub_request(:post, endpoint).to_return(status: status, body: body)
        runner = runner_for("prompt" => prompt)

        expect(runner.invoke).to eq(
          "error" => "Unexpected API response format",
          "status" => status,
          "body_preview" => body,
        )
        expect(runner.custom_raw).to be_nil
      end
    end

    it "reports responses containing text but no image" do
      parts = [{ text: "Unable to generate this image" }]
      stub_request(:post, endpoint).to_return(
        status: 200,
        body: { candidates: [{ content: { parts: parts } }] }.to_json,
      )
      runner = runner_for("prompt" => prompt)

      expect(runner.invoke).to eq(
        "error" => "No image data found in response",
        "parts_preview" => parts.to_json,
      )
      expect(runner.custom_raw).to be_nil
    end
  end

  context "with the Flare preset" do
    let(:preset_id) { "image_generation_openai" }

    include_examples "an OpenAI image preset", "gpt-image-2.6-flare"
  end

  context "with the Sunburst preset" do
    let(:preset_id) { "image_generation_openai_sunburst" }

    include_examples "an OpenAI image preset", "gpt-image-2.6-sunburst"
  end

  context "with the Nano Banana 2.1 preset" do
    let(:preset_id) { "image_generation_gemini" }

    include_examples "a Gemini image preset", "gemini-nano-banana-2.1"
  end

  context "with the Nano Banana Pro preset" do
    let(:preset_id) { "image_generation_gemini_pro" }

    include_examples "a Gemini image preset", "gemini-3-pro-image"
  end
end
