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
      let(:base64_script) { <<~JS }
        function invoke(params) {
          return upload.getBase64(params.upload_id, params.max_pixels);
        }
      JS

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

      context "with secure uploads" do
        fab!(:invoking_user, :user)
        fab!(:upload_owner, :user)
        fab!(:private_group, :group)
        fab!(:private_category) { Fabricate(:private_category, group: private_group) }
        fab!(:private_topic) { Fabricate(:topic, category: private_category, user: upload_owner) }
        fab!(:private_post) { Fabricate(:post, topic: private_topic, user: upload_owner) }
        let(:secure_upload) do
          upload = UploadCreator.new(jpg, "1x1.jpg").create_for(upload_owner.id)
          upload.update!(secure: true, access_control_post_id: private_post.id)
          upload
        end

        it "returns nil for a secure upload the guardian cannot see" do
          tool = create_tool(script: base64_script)

          runner =
            tool.runner(
              { "upload_id" => secure_upload.id },
              llm: nil,
              bot_user: nil,
              context: DiscourseAi::Agents::BotContext.new(user: invoking_user),
            )

          expect(runner.invoke).to be_nil
        end

        it "returns base64 when the guardian can see the access_control_post" do
          private_group.add(invoking_user)

          tool = create_tool(script: base64_script)

          runner =
            tool.runner(
              { "upload_id" => secure_upload.id, "max_pixels" => 1_000_000 },
              llm: nil,
              bot_user: nil,
              context: DiscourseAi::Agents::BotContext.new(user: invoking_user),
            )

          expect(runner.invoke).to be_a(String)
        end

        it "returns base64 when the context is built with only a user and the user can see the access_control_post" do
          private_group.add(invoking_user)

          tool = create_tool(script: base64_script)

          runner =
            tool.runner(
              { "upload_id" => secure_upload.id, "max_pixels" => 1_000_000 },
              llm: nil,
              bot_user: nil,
              context: DiscourseAi::Agents::BotContext.new(user: invoking_user),
            )

          expect(runner.invoke).to be_present
        end
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
