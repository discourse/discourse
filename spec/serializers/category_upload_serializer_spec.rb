# frozen_string_literal: true

RSpec.describe CategoryUploadSerializer do
  subject(:serializer) { described_class.new(upload, root: false) }

  fab!(:upload)

  it "should include width and height" do
    expect(serializer.width).to eq(upload.width)
    expect(serializer.height).to eq(upload.height)
  end
end
