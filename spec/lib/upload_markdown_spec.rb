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
    ![test\\_video.mp4|video](#{video.short_url})
    MD
    expect(UploadMarkdown.new(audio).to_markdown).to eq(<<~MD.chomp)
    ![test\\_audio.mp3|audio](#{audio.short_url})
    MD
    expect(UploadMarkdown.new(attachment).to_markdown).to eq(<<~MD.chomp)
    [test\\_file.pdf|attachment](#{attachment.short_url}) (#{attachment.human_filesize})
    MD
    expect(UploadMarkdown.new(image).to_markdown).to eq(<<~MD.chomp)
    ![test\\_img.jpg|100x200](#{image.short_url})
    MD

    unknown = Fabricate(:upload, original_filename: "test_video.mmmppp444", extension: "mmmppp444")
    expect(UploadMarkdown.new(unknown).playable_media_markdown).to eq(<<~MD.chomp)
    [test\\_video.mmmppp444|attachment](#{unknown.short_url}) (#{unknown.human_filesize})
    MD
  end

  it "escapes markdown characters in attachment filenames" do
    SiteSetting.authorized_extensions = "txt"

    {
      "_test_file_.txt" => "<em>",
      "*test*.txt" => "<em>",
      "**bold**.txt" => "<strong>",
      "~~strike~~.txt" => "<s>",
      "`code`.txt" => "<code>",
    }.each do |filename, bad_tag|
      upload = Fabricate(:upload, original_filename: filename, extension: "txt")
      markdown = UploadMarkdown.new(upload).attachment_markdown
      cooked = PrettyText.cook(markdown)

      expect(cooked).to include('class="attachment"'),
      "expected attachment class for filename: #{filename}\ncooked: #{cooked}"
      expect(cooked).not_to include(bad_tag),
      "unexpected #{bad_tag} in cooked output for filename: #{filename}\ncooked: #{cooked}"
      expect(cooked).to include(filename.gsub("\\", "")),
      "expected display name for filename: #{filename}\ncooked: #{cooked}"
    end
  end
end
