# frozen_string_literal: true

RSpec.describe UserExportSerializer do
  subject(:serializer) { UserExportSerializer.new(user_export, root: false) }

  fab!(:user_export) do
    user = Fabricate(:user)
    csv_file_1 = Fabricate(:upload, created_at: 1.day.ago)
    topic_1 = Fabricate(:topic, created_at: 1.day.ago)
    Fabricate(:post, topic: topic_1)
    UserExport.create!(
      file_name: "test",
      user: user,
      upload_id: csv_file_1.id,
      topic_id: topic_1.id,
      created_at: 1.day.ago,
    )
  end

  it "should render without errors" do
    json_data = JSON.parse(serializer.to_json)

    expect(json_data["id"]).to eql user_export.id
    expect(json_data["filename"]).to eql user_export.upload.original_filename
    expect(json_data["uri"]).to eql user_export.upload.short_path
    expect(json_data["filesize"]).to eql user_export.upload.filesize
    expect(json_data["extension"]).to eql user_export.upload.extension
    expect(json_data["retain_hours"]).to eql user_export.retain_hours
    expect(json_data["human_filesize"]).to eql user_export.upload.human_filesize
  end

  context "when upload is nil" do
    fab!(:user_export) do
      user = Fabricate(:user)
      topic = Fabricate(:topic, created_at: 1.day.ago)
      Fabricate(:post, topic: topic)
      UserExport.create!(
        file_name: "test",
        user: user,
        upload_id: nil,
        topic_id: topic.id,
        created_at: 1.day.ago,
      )
    end

    it "returns an empty hash" do
      json_data = JSON.parse(serializer.to_json)
      expect(json_data).to eq({})
    end
  end
end
