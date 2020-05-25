# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::MigrateGroupFlairImages do
  let(:image_url) { "https://omg.aws.somestack/test.png" }
  let(:group) { Fabricate(:group, flair_url: image_url) }

  before do
    stub_request(:get, image_url).to_return(
      status: 200, body: file_from_fixtures("smallest.png").read
    )
  end

  it 'should migrate to the new group `flair_upload_id` column correctly' do
    group

    expect do
      described_class.new.execute_onceoff({})
    end.to change { Upload.count }.by(1)

    group.reload
    expect(group.flair_upload).to eq(Upload.last)
    expect(group[:flair_url]).to eq(nil)
  end
end
