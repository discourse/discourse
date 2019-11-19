# frozen_string_literal: true

require 'rails_helper'

describe Jobs::UpdatePrivateUploadsAcl do
  let(:args) { [] }

  before do
    SiteSetting.authorized_extensions = "pdf"
  end

  describe '#execute' do
    context "if not SiteSetting.Upload.enable_s3_uploads" do
      before do
        SiteSetting.Upload.stubs(:enable_s3_uploads).returns(false)
      end
      it "returns early and changes no uploads" do
        Upload.expects(:find_each).never
        subject.execute(args)
      end
    end
    context "if SiteSetting.Upload.enable_s3_uploads" do
      let!(:upload) { Fabricate(:upload_s3, extension: 'pdf', original_filename: "watchmen.pdf", secure: false) }
      before do
        SiteSetting.login_required = true
        SiteSetting.prevent_anons_from_downloading_files = true
        SiteSetting::Upload.stubs(:enable_s3_uploads).returns(true)
        Discourse.stubs(:store).returns(stub(external?: false))
      end

      it "changes the upload to secure" do
        subject.execute(args)
        expect(upload.reload.secure).to eq(true)
      end
    end
  end
end
