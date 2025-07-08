# frozen_string_literal: true

RSpec.describe Jobs::SyncAccessControlForUploads do
  let(:upload1) { Fabricate(:upload) }
  let(:upload2) { Fabricate(:upload) }
  let(:upload3) { Fabricate(:secure_upload) }
  let(:upload_ids) { [upload1.id, upload2.id, upload3.id] }

  def run_job
    described_class.new.execute(upload_ids: upload_ids)
  end

  it "does nothing if not using external storage" do
    Upload.expects(:where).never
    run_job
  end

  context "with external storage enabled" do
    before do
      setup_s3
      stub_s3_store
    end

    it "runs update_upload_access_control for each upload" do
      Discourse.store.expects(:update_upload_access_control).times(3)
      run_job
    end

    it "handles updates throwing an exception" do
      Discourse
        .store
        .expects(:update_upload_access_control)
        .raises(StandardError)
        .then
        .returns(true, true)
        .times(3)
      Discourse.expects(:warn_exception).once
      run_job
    end
  end
end
