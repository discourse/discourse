# frozen_string_literal: true

require 'rails_helper'

describe ShrinkUploadedImage do
  let(:upload) { Fabricate(:image_upload, width: 200, height: 200) }

  it "resizes the image" do
    filesize_before = upload.filesize
    post = Fabricate(:post, raw: "<img src='#{upload.url}'>")
    post.link_post_uploads

    result = ShrinkUploadedImage.new(
      upload: upload,
      path: Discourse.store.path_for(upload),
      max_pixels: 10_000
    ).perform

    expect(result).to be(true)
    expect(upload.width).to eq(100)
    expect(upload.height).to eq(100)
    expect(upload.filesize).to be < filesize_before
  end

  it "returns false if the image cannot be shrunk more" do
    post = Fabricate(:post, raw: "<img src='#{upload.url}'>")
    post.link_post_uploads
    ShrinkUploadedImage.new(
      upload: upload,
      path: Discourse.store.path_for(upload),
      max_pixels: 10_000
    ).perform

    upload.reload

    result = ShrinkUploadedImage.new(
      upload: upload,
      path: Discourse.store.path_for(upload),
      max_pixels: 10_000
    ).perform

    expect(result).to be(false)
  end
end
