# frozen_string_literal: true

RSpec.describe Jobs::UpdateAnimatedUploads do
  let!(:upload) { Fabricate(:upload) }
  let!(:gif_upload) { Fabricate(:upload, extension: "gif") }

  before do
    DiscourseImage.stubs(:animated?).returns(true)
    SafeImage.stubs(:remote_animated?).returns(true)
  end

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
end
