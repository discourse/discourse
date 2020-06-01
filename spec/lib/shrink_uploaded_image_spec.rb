# frozen_string_literal: true

require 'rails_helper'

describe ShrinkUploadedImage do
  let(:upload) { Fabricate(:s3_image_upload, width: 200, height: 200) }
  let(:path) { Discourse.store.download(upload).path }

  it "resizes the image" do
    filesize_before = upload.filesize
    result = ShrinkUploadedImage.new(upload: upload, path: path, max_pixels: 10_000).perform

    expect(result).to be(true)
    expect(upload.width).to eq(100)
    expect(upload.height).to eq(100)
    expect(upload.filesize).to be < filesize_before
  end

  it "returns false if the image cannot be shrunk more" do
    ShrinkUploadedImage.new(upload: upload, path: path, max_pixels: 10_000).perform
    result = ShrinkUploadedImage.new(upload: upload, path: path, max_pixels: 10_000).perform

    expect(result).to be(false)
  end
end
