# frozen_string_literal: true

require 'rails_helper'

describe CategoryUploadSerializer do

  fab!(:upload) { Fabricate(:upload) }
  let(:subject) { described_class.new(upload, root: false) }

  it 'should include width and height' do
    expect(subject.width).to eq(upload.width)
    expect(subject.height).to eq(upload.height)
  end

end
