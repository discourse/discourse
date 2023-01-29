# frozen_string_literal: true

RSpec.describe Jobs::MigrateBadgeImageToUploads do
  let(:image_url) { "https://omg.aws.somestack/test.png" }
  let(:badge) { Fabricate(:badge) }

  before do
    @orig_logger = Rails.logger
    Rails.logger = @fake_logger = FakeLogger.new
  end

  after { Rails.logger = @orig_logger }

  it "should migrate to the new badge `image_upload_id` column correctly" do
    stub_request(:get, image_url).to_return(
      status: 200,
      body: file_from_fixtures("smallest.png").read,
    )
    DB.exec(<<~SQL, flair_url: image_url, id: badge.id)
      UPDATE badges SET image = :flair_url WHERE id = :id
    SQL

    expect do described_class.new.execute_onceoff({}) end.to change { Upload.count }.by(1)

    badge.reload
    upload = Upload.last
    expect(badge.image_upload).to eq(upload)
    expect(badge.image_url).to eq(upload.url)
    expect(badge[:image]).to eq(nil)
  end

  it "should skip badges with invalid flair URLs" do
    DB.exec("UPDATE badges SET image = 'abc' WHERE id = ?", badge.id)
    described_class.new.execute_onceoff({})
    expect(@fake_logger.warnings.count).to eq(0)
    expect(@fake_logger.errors.count).to eq(0)
  end

  # this case has a couple of hacks that are needed to test this behavior, so if it
  # starts failing randomly in the future, I'd just delete it and not bother with it
  it "should not keep retrying forever if download fails" do
    stub_request(:get, image_url).to_return(status: 403)
    instance = described_class.new
    instance.expects(:sleep).times(2)

    DB.exec(<<~SQL, flair_url: image_url, id: badge.id)
      UPDATE badges SET image = :flair_url WHERE id = :id
    SQL

    expect do instance.execute_onceoff({}) end.not_to change { Upload.count }

    badge.reload
    expect(badge.image_upload).to eq(nil)
    expect(badge.image_url).to eq(nil)
    expect(Badge.where(id: badge.id).select(:image).first[:image]).to eq(image_url)
    expect(@fake_logger.warnings.count).to eq(3)
  end
end
