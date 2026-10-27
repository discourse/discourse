# frozen_string_literal: true

require "file_store/to_s3_migration"

RSpec.describe FileStore::ToS3Migration do
  describe "#migrate" do
    it "remaps relative and absolute form URLs, including omitted answers, in one pass" do
      GlobalSetting.stubs(:cdn_url).returns("https://old-cdn.example.com")
      db = RailsMultisite::ConnectionManagement.current_db
      path = "/uploads/#{db}/original/1X/#{"a" * 40}.png"
      template =
        Fabricate(
          :form_template,
          template: [
            { id: "image", type: "composer" },
            { id: "hidden", type: "composer" },
          ].as_json.to_yaml,
          output_template: "{{ answers.image }}",
        )
      submission =
        FormTemplate::Submission.from_template(
          template,
          answers: {
            "image" => "![](#{Discourse.base_url}#{path})",
            "hidden" => "![](#{path})",
          },
        )
      post = Fabricate(:post, raw: submission.normalized_raw, form_data: submission.to_h)
      Upload.by_users.delete_all
      setup_s3
      # File transfer is outside this regression; exercise the real URL migration
      # with an empty local inventory and the SDK's stubbed S3 responses.
      IO
        .stubs(:popen)
        .with("cd #{Rails.public_path} && find uploads/#{db}/original -type f")
        .returns(StringIO.new(""))
      migration =
        described_class.new(
          s3_options: {
            bucket: SiteSetting.s3_upload_bucket,
            client_options: {
              stub_responses: true,
              region: "us-west-1",
            },
          },
          migrate_to_multisite: true,
        )

      migration.migrate

      expected = "![](#{SiteSetting.Upload.s3_base_url}#{path})"
      expect(post.reload.form_submission.answers.values).to eq([expected, expected])
      expect(post.raw).to eq(expected)
      edited =
        post.form_submission.with_answers(post.form_submission.answers.merge("hidden" => "Updated"))
      expect(post.update(raw: edited.normalized_raw, form_data: edited.to_h)).to eq(true)
      expect(post.reload.raw).to eq(expected)
    end
  end
end
