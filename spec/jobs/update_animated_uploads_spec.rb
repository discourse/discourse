# frozen_string_literal: true

RSpec.describe Jobs::UpdateAnimatedUploads do
  let!(:upload) { Fabricate(:upload) }
  let!(:gif_upload) { Fabricate(:upload, extension: "gif") }

  let(:gif_path) { Discourse.store.path_for(gif_upload) }

  before do
    FileUtils.mkdir_p(File.dirname(gif_path))
    FileUtils.touch(gif_path)
    FastImage.expects(:animated?).with(gif_path).returns(true).once
  end

  after { FileUtils.rm_f(gif_path) }

  it "affects only GIF uploads" do
    described_class.new.execute({})

    expect(upload.reload.animated).to eq(nil)
    expect(gif_upload.reload.animated).to eq(true)
  end

  it "works with uploads larger than current limits" do
    SiteSetting.max_image_size_kb = 1

    described_class.new.execute({})

    expect(gif_upload.reload.animated).to eq(true)
  end

  it "only reads GIFs from the store" do
    stub_request(:get, "http://example.com/remote.gif").to_return(status: 404)
    Fabricate(:upload, extension: "gif").update_columns(url: "http://example.com/remote.gif")

    described_class.new.execute({})

    expect(gif_upload.reload.animated).to eq(true)
  end
end
