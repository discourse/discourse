# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::RagDocumentFragmentsController do
  fab!(:admin)
  fab!(:ai_persona)

  fab!(:vector_def, :embedding_definition)

  before do
    enable_current_plugin
    sign_in(admin)
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    SiteSetting.ai_embeddings_enabled = true
  end

  after { @cleanup_files&.each(&:unlink) }

  describe "GET #indexing_status_check" do
    it "works for AiPersona" do
      get "/admin/plugins/discourse-ai/rag-document-fragments/files/status.json?target_type=AiPersona&target_id=#{ai_persona.id}"

      expect(response.parsed_body).to eq({})
      expect(response.status).to eq(200)
    end
  end

  describe "POST #upload_file" do
    let :fake_image do
      @cleanup_files ||= []
      tempfile = Tempfile.new(%w[test .png])
      tempfile.write("fake image")
      tempfile.rewind
      @cleanup_files << tempfile
      tempfile
    end

    it "works" do
      post "/admin/plugins/discourse-ai/rag-document-fragments/files/upload.json",
           params: {
             file: Rack::Test::UploadedFile.new(file_from_fixtures("spec.txt", "md")),
           }

      expect(response.status).to eq(200)

      upload = Upload.last
      expect(upload.original_filename).to end_with("spec.txt")
    end

    it "rejects PDF files if site setting is not enabled" do
      SiteSetting.ai_rag_images_enabled = false

      post "/admin/plugins/discourse-ai/rag-document-fragments/files/upload.json",
           params: {
             file: Rack::Test::UploadedFile.new(fake_image),
           }

      expect(response.status).to eq(400)
    end

    it "allows image files if site setting is enabled" do
      SiteSetting.ai_rag_images_enabled = true

      post "/admin/plugins/discourse-ai/rag-document-fragments/files/upload.json",
           params: {
             file: Rack::Test::UploadedFile.new(fake_image),
           }

      upload = Upload.last
      expect(upload.original_filename).to end_with(".png")
    end
  end
end
