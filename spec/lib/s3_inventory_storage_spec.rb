# frozen_string_literal: true

require "s3_inventory"

RSpec.describe S3Inventory do
  let(:endpoint) { "https://inventory.example.test" }
  let(:client) do
    Aws::S3::Client.new(
      endpoint:,
      region: "us-east-1",
      credentials: Aws::Credentials.new("test", "test"),
      force_path_style: true,
      retry_limit: 0,
    )
  end
  let(:inventory) do
    described_class.new(:upload, s3_inventory_bucket: "uploads/site", s3_options: { client: })
  end

  before { stub_request(:head, "#{endpoint}/uploads").to_return(status: 200) }

  it "logs service failures on a later listing page without using a partial inventory" do
    stub_request(:get, "#{endpoint}/uploads").with(
      query: {
        "list-type" => "2",
        "prefix" => "site/hive",
      },
    ).to_return(
      status: 200,
      body:
        "<ListBucketResult><IsTruncated>true</IsTruncated><NextContinuationToken>next</NextContinuationToken><Contents><Key>site/hive/symlink.txt</Key><LastModified>2026-01-01T00:00:00Z</LastModified><Size>1</Size></Contents></ListBucketResult>",
    )
    request =
      stub_request(:get, "#{endpoint}/uploads").with(
        query: {
          "list-type" => "2",
          "prefix" => "site/hive",
          "continuation-token" => "next",
        },
      ).to_return(status: 403, body: "<Error><Code>AccessDenied</Code></Error>")

    expect { inventory.backfill_etags_and_list_missing }.to output(
      "Failed to list inventory from S3\nFailed to list inventory from S3\n",
    ).to_stdout
    expect(request).to have_been_requested.once
  end

  it "preserves transport failures during inventory listing" do
    stub_request(:get, "#{endpoint}/uploads").with(
      query: {
        "list-type" => "2",
        "prefix" => "site/hive",
      },
    ).to_timeout
    expect { inventory.backfill_etags_and_list_missing }.to raise_error(
      Seahorse::Client::NetworkingError,
    ) do |error|
      expect(error.original_error).to be_a(Timeout::Error)
      expect(error.cause).not_to be_a(FileStore::ObjectStorage::Error)
    end
  end

  it "downloads inventory bytes and reuses an existing local file" do
    stub_request(:head, "#{endpoint}/uploads/site/data.csv.gz?partNumber=1").to_return(
      status: 200,
      headers: {
        "Content-Length" => "5",
      },
    )
    request = stub_request(:get, "#{endpoint}/uploads/site/data.csv.gz").to_return(body: "bytes")
    Dir.mktmpdir do |directory|
      file = { key: "site/data.csv.gz", filename: File.join(directory, "data.csv.gz") }
      capture_stdout do
        inventory.download_inventory_file_to_tmp_directory(file)
        inventory.download_inventory_file_to_tmp_directory(file)
      end
      expect(File.binread(file[:filename])).to eq("bytes")
    end
    expect(request).to have_been_requested.once
  end

  it "preserves the custom download failure message and direct SDK cause" do
    stub_request(:head, "#{endpoint}/uploads/site/data.csv.gz?partNumber=1").to_return(status: 403)
    Dir.mktmpdir do |directory|
      file = { key: "site/data.csv.gz", filename: File.join(directory, "data.csv.gz") }
      expect {
        capture_stdout { inventory.download_inventory_file_to_tmp_directory(file) }
      }.to raise_error(
        RuntimeError,
        "Failed to inventory file 'site/data.csv.gz' to tmp directory.",
      ) do |error|
        expect(error.cause).to be_a(Aws::S3::Errors::ServiceError)
      end
    end
  end
end
