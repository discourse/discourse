# frozen_string_literal: true

require "file_store/to_s3_migration"

RSpec.describe FileStore::ToS3Migration do
  before do
    setup_s3
    SiteSetting.s3_upload_bucket = "uploads/site"
    Upload.by_users.update_all(url: "#{SiteSetting.Upload.s3_base_url}/original/file.txt")
  end

  let(:options) do
    {
      bucket: "uploads/site",
      client_options: {
        endpoint: "https://migration.example.test",
        region: "us-east-1",
        credentials: Aws::Credentials.new("test", "test"),
        force_path_style: true,
        retry_limit: 0,
      },
    }
  end

  it "lists through the configured bucket folder in dry run without transferring local files" do
    request =
      stub_request(:get, "https://migration.example.test/uploads").with(
        query: {
          "list-type" => "2",
          "prefix" => "site/original/",
        },
      ).to_return(
        status: 200,
        body: "<ListBucketResult><IsTruncated>false</IsTruncated></ListBucketResult>",
      )
    Dir.mktmpdir do |directory|
      Rails.stubs(:public_path).returns(Pathname.new(directory))
      FileUtils.mkdir_p(File.join(directory, "uploads/default/original"))
      File.write(File.join(directory, "uploads/default/original/file.txt"), "bytes")
      output = capture_stdout { described_class.new(s3_options: options, dry_run: true).migrate }
      expect(output).to include("uploads/default/original/file.txt => site/original/file.txt")
      expect(output).to include("Done!")
    end
    expect(request).to have_been_requested.once
    expect(a_request(:put, %r{\Ahttps://migration.example.test/})).not_to have_been_made
  end

  it "uploads local bytes with a checksum through the migration workflow" do
    stub_request(:get, "https://migration.example.test/uploads").with(
      query: {
        "list-type" => "2",
        "prefix" => "site/original/",
      },
    ).to_return(
      status: 200,
      body: "<ListBucketResult><IsTruncated>false</IsTruncated></ListBucketResult>",
    )
    request =
      stub_request(:put, "https://migration.example.test/uploads/site/original/file.txt").with(
        body: "bytes",
        headers: {
          "Content-Md5" => Digest::MD5.base64digest("bytes"),
          "X-Amz-Acl" => "public-read",
        },
      ).to_return(status: 200, headers: { "ETag" => '"etag"' })
    Dir.mktmpdir do |directory|
      Rails.stubs(:public_path).returns(Pathname.new(directory))
      FileUtils.mkdir_p(File.join(directory, "uploads/default/original"))
      File.write(File.join(directory, "uploads/default/original/file.txt"), "bytes")
      output = capture_stdout { described_class.new(s3_options: options).migrate }
      expect(output).to include("Done!")
    end
    expect(request).to have_been_requested.once
  end

  it "skips matching remote files after reading every listing page" do
    first =
      stub_request(:get, "https://migration.example.test/uploads").with(
        query: {
          "list-type" => "2",
          "prefix" => "site/original/",
        },
      ).to_return(
        status: 200,
        body:
          "<ListBucketResult><IsTruncated>true</IsTruncated><NextContinuationToken>next</NextContinuationToken></ListBucketResult>",
      )
    second =
      stub_request(:get, "https://migration.example.test/uploads").with(
        query: {
          "list-type" => "2",
          "prefix" => "site/original/",
          "continuation-token" => "next",
        },
      ).to_return(
        status: 200,
        body:
          "<ListBucketResult><IsTruncated>false</IsTruncated><Contents><Key>site/original/file.txt</Key><Size>5</Size></Contents></ListBucketResult>",
      )
    Dir.mktmpdir do |directory|
      Rails.stubs(:public_path).returns(Pathname.new(directory))
      FileUtils.mkdir_p(File.join(directory, "uploads/default/original"))
      File.write(File.join(directory, "uploads/default/original/file.txt"), "bytes")
      output = capture_stdout { described_class.new(s3_options: options).migrate }
      expect(output).to include("Done!")
    end
    expect(first).to have_been_requested.once
    expect(second).to have_been_requested.once
    expect(a_request(:put, %r{\Ahttps://migration.example.test/})).not_to have_been_made
  end
end
