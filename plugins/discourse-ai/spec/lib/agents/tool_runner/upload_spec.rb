# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Agents::ToolRunner do
  fab!(:bot_user) { Discourse.system_user }

  def create_tool(script:)
    AiTool.create!(
      name: "test #{SecureRandom.uuid}",
      tool_name: "test_#{SecureRandom.uuid.underscore}",
      description: "test",
      parameters: [{ name: "query", type: "string", description: "perform a search" }],
      script: script,
      created_by_id: 1,
      summary: "Test tool summary",
    )
  end

  before { enable_current_plugin }

  let(:jpg) { plugin_file_from_fixtures("1x1.jpg") }

  describe "upload operations" do
    describe "upload base64 encoding" do
      it "can get base64 data from upload ID and short URL" do
        upload = UploadCreator.new(jpg, "1x1.jpg").create_for(Discourse.system_user.id)

        script_id = <<~JS
          function invoke(params) {
            return upload.getBase64(params.upload_id, params.max_pixels);
          }
        JS

        tool = create_tool(script: script_id)
        runner =
          tool.runner(
            { "upload_id" => upload.id, "max_pixels" => 1_000_000 },
            llm: nil,
            bot_user: nil,
          )
        result_id = runner.invoke

        expect(result_id).to be_present
        expect(result_id).to be_a(String)
        expect(result_id.length).to be > 0

        script_url = <<~JS
          function invoke(params) {
            return upload.getBase64(params.short_url, params.max_pixels);
          }
        JS

        tool = create_tool(script: script_url)
        runner =
          tool.runner(
            { "short_url" => upload.short_url, "max_pixels" => 1_000_000 },
            llm: nil,
            bot_user: nil,
          )
        result_url = runner.invoke

        expect(result_url).to be_present
        expect(result_url).to be_a(String)
        expect(result_url).to eq(result_id)

        script_invalid = <<~JS
          function invoke(params) {
            return upload.getBase64(99999);
          }
        JS

        tool = create_tool(script: script_invalid)
        runner = tool.runner({}, llm: nil, bot_user: nil)
        result_invalid = runner.invoke

        expect(result_invalid).to be_nil
      end
    end

    describe "upload URL resolution" do
      it "can resolve upload short URLs to public URLs" do
        upload =
          Fabricate(
            :upload,
            sha1: "abcdef1234567890abcdef1234567890abcdef12",
            url: "/uploads/default/original/1X/test.jpg",
            original_filename: "test.jpg",
          )

        script = <<~JS
        function invoke(params) {
          return upload.getUrl(params.short_url);
        }
      JS

        tool = create_tool(script: script)
        runner = tool.runner({ "short_url" => upload.short_url }, llm: nil, bot_user: nil)

        result = runner.invoke

        expect(result).to eq(GlobalPath.full_cdn_url(upload.url))
      end

      it "returns null for invalid upload short URLs" do
        script = <<~JS
        function invoke(params) {
          return upload.getUrl(params.short_url);
        }
      JS

        tool = create_tool(script: script)
        runner = tool.runner({ "short_url" => "upload://invalid" }, llm: nil, bot_user: nil)

        result = runner.invoke

        expect(result).to be_nil
      end

      it "returns null for non-existent uploads" do
        script = <<~JS
        function invoke(params) {
          return upload.getUrl(params.short_url);
        }
      JS

        tool = create_tool(script: script)
        runner =
          tool.runner(
            { "short_url" => "upload://hwmUkTAL9mwhQuRMLsXw6tvDi5C.jpeg" },
            llm: nil,
            bot_user: nil,
          )

        result = runner.invoke

        expect(result).to be_nil
      end
    end
  end
end
