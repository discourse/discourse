# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::MigrateGroupFlairImages do
  let(:image_url) { "https://omg.aws.somestack/test.png" }
  let(:group) { Fabricate(:group) }

  before do
    stub_request(:get, image_url).to_return(
      status: 200, body: file_from_fixtures("smallest.png").read
    )
    @orig_logger = Rails.logger
    Rails.logger = @fake_logger = FakeLogger.new
  end

  after do
    Rails.logger = @orig_logger
  end

  it 'should migrate to the new group `flair_upload_id` column correctly' do
    DB.exec(<<~SQL, flair_url: image_url)
      UPDATE groups SET flair_url = :flair_url WHERE id = #{group.id}
    SQL

    expect do
      described_class.new.execute_onceoff({})
    end.to change { Upload.count }.by(1)

    group.reload
    upload = Upload.last
    expect(group.flair_upload).to eq(upload)
    expect(group.flair_url).to eq(upload.short_path)
    expect(group[:flair_url]).to eq(nil)
  end

  it 'should skip groups with invalid flair URLs' do
    DB.exec("UPDATE groups SET flair_url = 'abc' WHERE id = #{group.id}")
    described_class.new.execute_onceoff({})
    expect(Rails.logger.warnings.count).to eq(0)
  end
end
