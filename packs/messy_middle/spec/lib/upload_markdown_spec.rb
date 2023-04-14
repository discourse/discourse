# frozen_string_literal: true

RSpec.describe UploadMarkdown do
  it "generates markdown for each different upload type (attachment, image, video, audio)" do
    SiteSetting.authorized_extensions = "mp4|mp3|pdf|jpg|mmmppp444"
    video = Fabricate(:upload, original_filename: "test_video.mp4", extension: "mp4")
    audio = Fabricate(:upload, original_filename: "test_audio.mp3", extension: "mp3")
    attachment = Fabricate(:upload, original_filename: "test_file.pdf", extension: "pdf")
    image =
      Fabricate(
        :upload,
        width: 100,
        height: 200,
        original_filename: "test_img.jpg",
        extension: "jpg",
      )

    expect(UploadMarkdown.new(video).to_markdown).to eq(<<~MD.chomp)
    ![test_video.mp4|video](#{video.short_url})
    MD
    expect(UploadMarkdown.new(audio).to_markdown).to eq(<<~MD.chomp)
    ![test_audio.mp3|audio](#{audio.short_url})
    MD
    expect(UploadMarkdown.new(attachment).to_markdown).to eq(<<~MD.chomp)
    [test_file.pdf|attachment](#{attachment.short_url}) (#{attachment.human_filesize})
    MD
    expect(UploadMarkdown.new(image).to_markdown).to eq(<<~MD.chomp)
    ![test_img.jpg|100x200](#{image.short_url})
    MD

    unknown = Fabricate(:upload, original_filename: "test_video.mmmppp444", extension: "mmmppp444")
    expect(UploadMarkdown.new(unknown).playable_media_markdown).to eq(<<~MD.chomp)
    [test_video.mmmppp444|attachment](#{unknown.short_url}) (#{unknown.human_filesize})
    MD
  end
end
