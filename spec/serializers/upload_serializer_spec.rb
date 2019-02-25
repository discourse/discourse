require 'rails_helper'

RSpec.describe UploadSerializer do
  let(:upload) { Fabricate(:upload) }
  let(:subject) { UploadSerializer.new(upload, root: false) }

  it 'should render without errors' do
    json_data = JSON.load(subject.to_json)

    expect(json_data['id']).to eql upload.id
    expect(json_data['width']).to eql upload.width
    expect(json_data['height']).to eql upload.height
    expect(json_data['thumbnail_width']).to eql upload.thumbnail_width
    expect(json_data['thumbnail_height']).to eql upload.thumbnail_height
  end
end
