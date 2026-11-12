# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::SiteSettings do
  subject(:configure) { described_class.configure!(options) }

  let(:options) do
    {
      authorized_extensions: "*",
      max_attachment_size_kb: 102_400,
      max_image_size_kb: 102_400,
      max_image_megapixels: 150,
      secure_uploads: false,
      s3_enable_access_control_tags: true,
      enable_s3_uploads: true,
      s3_upload_bucket: "uploads.example.com",
      s3_region: "us-east-1",
      s3_access_key_id: "access-key",
      s3_secret_access_key: "secret-key",
      s3_cdn_url: "",
      multisite: false,
    }
  end

  let(:site_setting_class) do
    Class.new do
      class << self
        attr_accessor :clean_up_uploads,
                      :authorized_extensions,
                      :max_attachment_size_kb,
                      :max_image_size_kb,
                      :max_image_megapixels,
                      :secure_uploads,
                      :s3_enable_access_control_tags,
                      :s3_access_key_id,
                      :s3_secret_access_key,
                      :s3_upload_bucket,
                      :s3_region,
                      :s3_cdn_url,
                      :s3_endpoint,
                      :enable_s3_uploads
      end
    end
  end

  let(:upload) do
    double(
      persisted?: true,
      errors: [],
      url: "//uploads.example.com/original/test.txt",
      destroy: true,
    )
  end

  before do
    stub_const("SiteSetting", site_setting_class)
    stub_const("Discourse", Module.new)
    stub_const("Discourse::SYSTEM_USER_ID", -1)

    upload_creator = double(create_for: upload)
    upload_creator_class = class_double("UploadCreator", new: upload_creator)
    stub_const("UploadCreator", upload_creator_class)
  end

  it "rejects an S3 configuration whose uploads cannot be read without credentials" do
    response = Net::HTTPForbidden.new("1.1", "403", "Forbidden")
    allow(Net::HTTP).to receive(:get_response).and_return(response)

    expect { configure }.to raise_error(
      described_class::S3UploadsConfigurationError,
      /could not be read without credentials \(HTTP 403\)/,
    )
  end

  it "does not require anonymous access when secure uploads are enabled" do
    options[:secure_uploads] = true
    response = Net::HTTPForbidden.new("1.1", "403", "Forbidden")
    allow(Net::HTTP).to receive(:get_response).and_return(response)

    expect { configure }.not_to raise_error
  end

  it "checks public access with the endpoint's scheme" do
    options[:s3_endpoint] = "http://minio.local:9000"
    SiteSetting.s3_endpoint = options[:s3_endpoint]
    allow(Net::HTTP).to receive(:get_response).and_return(Net::HTTPOK.new("1.1", "200", "OK"))

    configure

    expect(Net::HTTP).to have_received(:get_response).with(
      an_object_satisfying { |uri| uri.scheme == "http" },
    )
  end

  it "warns when S3 is configured but disabled" do
    options[:enable_s3_uploads] = false

    expect { configure }.to output(/enable_s3_uploads is false/).to_stderr
  end
end
