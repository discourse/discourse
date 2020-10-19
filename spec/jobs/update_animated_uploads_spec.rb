# frozen_string_literal: true

require 'rails_helper'

describe Jobs::UpdateAnimatedUploads do
  let!(:upload) { Fabricate(:upload) }
  let!(:gif_upload) { Fabricate(:upload, extension: "gif") }

  it "affects only GIF uploads" do
    url = Discourse.store.path_for(gif_upload) || gif_upload.url
    FastImage.expects(:animated?).with(url).returns(true).once

    described_class.new.execute({})

    expect(upload.reload.animated).to eq(nil)
    expect(gif_upload.reload.animated).to eq(true)
  end
end
