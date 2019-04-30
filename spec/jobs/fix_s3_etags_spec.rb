# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::FixS3Etags do
  let(:etag_with_quotes) { '"ETag"' }
  let(:etag_without_quotes) { 'ETag' }

  it 'should remove double quotes from etags' do
    upload1 = Fabricate(:upload, etag: etag_with_quotes)
    upload2 = Fabricate(:upload, etag: etag_without_quotes)
    optimized = Fabricate(:optimized_image, etag: etag_with_quotes)

    described_class.new.execute_onceoff({})

    upload1.reload
    upload2.reload
    optimized.reload

    expect(upload1.etag).to eq(etag_without_quotes)
    expect(upload2.etag).to eq(etag_without_quotes)
    expect(optimized.etag).to eq(etag_without_quotes)
  end
end
