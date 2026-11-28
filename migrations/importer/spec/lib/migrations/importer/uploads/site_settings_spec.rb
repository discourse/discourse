# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::SiteSettings do
  subject(:configure) { described_class.configure!(options) }

  let(:options) do
    {
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

        def get(name)
          instance_variable_get(:"@#{name}")
        end

        def set(name, value)
          instance_variable_set(:"@#{name}", value)
        end
      end
    end
  end

  let(:upload) do
    instance_double(
      "Upload",
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

    upload_creator = instance_double("UploadCreator", create_for: upload)
    class_double("UploadCreator", new: upload_creator).as_stubbed_const
  end

  def stub_public_access(response)
    allow(Net::HTTP).to receive(:get_response).and_return(response)
  end

  it "rejects an S3 configuration whose uploads cannot be read without credentials" do
    stub_public_access(Net::HTTPForbidden.new("1.1", "403", "Forbidden"))

    expect { configure }.to raise_error(
      described_class::S3UploadsConfigurationError,
      /could not be read without credentials \(HTTP 403\)/,
    )
  end

  it "does not require anonymous access when secure uploads are enabled" do
    options[:secure_uploads] = true
    stub_public_access(Net::HTTPForbidden.new("1.1", "403", "Forbidden"))

    expect { configure }.not_to raise_error
  end

  it "points the store at the configured endpoint and checks public access with its scheme" do
    options[:s3_endpoint] = "http://minio.local:9000"
    stub_public_access(Net::HTTPOK.new("1.1", "200", "OK"))

    configure

    expect(SiteSetting.s3_endpoint).to eq("http://minio.local:9000")
    expect(Net::HTTP).to have_received(:get_response).with(
      an_object_satisfying { |uri| uri.scheme == "http" },
    )
  end

  it "clears an endpoint the target site has when the settings file has none" do
    SiteSetting.s3_endpoint = "http://minio.local:9000"
    stub_public_access(Net::HTTPOK.new("1.1", "200", "OK"))

    configure

    expect(SiteSetting.s3_endpoint).to eq("")
  end

  it "warns and leaves the S3 settings alone when S3 is configured but disabled" do
    SiteSetting.s3_endpoint = "http://minio.local:9000"
    options[:enable_s3_uploads] = false

    expect { configure }.to output(/enable_s3_uploads is false/).to_stderr
    expect(SiteSetting.s3_endpoint).to eq("http://minio.local:9000")
  end

  it "puts the previous S3 settings back when the check fails" do
    SiteSetting.enable_s3_uploads = false
    SiteSetting.s3_upload_bucket = "old-bucket"
    SiteSetting.s3_access_key_id = "old-key"
    SiteSetting.s3_endpoint = "http://old.local"
    stub_public_access(Net::HTTPForbidden.new("1.1", "403", "Forbidden"))

    expect { configure }.to raise_error(described_class::S3UploadsConfigurationError)

    expect(SiteSetting.enable_s3_uploads).to be(false)
    expect(SiteSetting.s3_upload_bucket).to eq("old-bucket")
    expect(SiteSetting.s3_access_key_id).to eq("old-key")
    expect(SiteSetting.s3_endpoint).to eq("http://old.local")
    expect(SiteSetting.s3_secret_access_key).to be_nil
  end

  it "keeps the new S3 settings when the check passes" do
    SiteSetting.s3_upload_bucket = "old-bucket"
    stub_public_access(Net::HTTPOK.new("1.1", "200", "OK"))

    configure

    expect(SiteSetting.enable_s3_uploads).to be(true)
    expect(SiteSetting.s3_upload_bucket).to eq("uploads.example.com")
  end
end
