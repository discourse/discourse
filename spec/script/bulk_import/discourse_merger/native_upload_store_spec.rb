# frozen_string_literal: true

require_relative "../../../../script/bulk_import/native_upload_store"
require "tmpdir"
require_relative "../../../../script/bulk_import/discourse_merger/cli"

RSpec.describe BulkImport::NativeUploadStore do
  let(:settings) do
    {
      enable_s3_uploads: true,
      s3_upload_bucket: "shared/sites",
      s3_region: "us-west-2",
      multisite: true,
      multisite_db_name: "target",
      s3_cdn_url: "https://cdn.example",
      s3_access_key_id: "test-key",
      s3_secret_access_key: "test-secret",
      s3_use_acls: false,
      s3_enable_access_control_tags: true,
      s3_access_control_tag_key: "discourse:acl",
      s3_access_control_tag_public_value: "public",
      s3_access_control_tag_private_value: "private",
    }
  end
  let(:client) { Aws::S3::Client.new(region: "us-west-2", stub_responses: true) }
  let(:store) { described_class.new(settings, client: client) }
  let(:file_key) { "original/1X/abc.pdf" }

  before do
    unless defined?(Rails)
      require "mini_mime"
      stub_const("SiteSetting", Class.new { def self.s3_max_age = 100 })
      stub_const(
        "S3Helper",
        Class.new { def self.get_bucket_and_folder_path(value) = value.split("/", 2) },
      )
      stub_const("FileStore::S3Store", Class.new { def self.content_disposition_for(_) = "inline" })
    end
  end

  describe "native preparation" do
    let(:write) { "s3://shared/sites/uploads/target" }
    let(:retained) { "s3://shared/retained" }
    let(:locations) { { "write" => write, "read_prefixes" => { "destination" => retained } } }
    let(:project) do
      {
        "source" => {
          "dbname" => "source",
        },
        "destination" => {
          "dbname" => "destination",
        },
        "source_url" => "https://source.example",
        "destination_url" => "https://destination.example",
        "upload_mode" => "preuploaded",
        "preupload_locations" => locations,
      }
    end
    let(:uploader) do
      {
        "site_settings" => settings.stringify_keys,
        "preupload_read_prefixes" => {
          "destination" => retained,
        },
      }
    end

    it "rejects a different write location or read side before opening receipts or contacting S3" do
      allow(Aws::S3::Client).to receive(:new).and_return(client)
      Dir.mktmpdir do |dir|
        directory = Pathname(dir)
        receipts = directory.join("prepared-uploads.sqlite3")
        receipts.write("existing receipts")
        path = directory.join("uploader.yml")
        path.write(uploader.to_yaml)
        [
          [nil, "preupload_locations.write"],
          [{ "write" => "s3://other/sites/uploads/target" }, "resolved #{write}"],
          [{ "write" => "s3://shared/sites/target" }, "resolved #{write}"],
          [{ "write" => write }, "expected (none), resolved #{retained}"],
          [locations.deep_merge("read_prefixes" => { "source" => retained }), "resolved (none)"],
          [
            { "write" => write, "read_prefixes" => { "source" => retained } },
            "read_prefixes.source",
          ],
          [
            locations.deep_merge("read_prefixes" => { "destination" => write }),
            "expected #{write}, resolved #{retained}",
          ],
        ].each do |expected, diagnostic|
          directory.join("merge.yml").write(
            project.merge("preupload_locations" => expected).to_yaml,
          )
          expect {
            status =
              BulkImport::DiscourseMerge::CLI.run(
                ["prepare-uploads", "--directory", dir, "--settings", path.to_s],
              )
            expect(status).to eq(1)
          }.to output(/#{Regexp.escape(diagnostic)}/).to_stderr
          expect(receipts.read).to eq("existing receipts")
          expect(client.api_requests).to be_empty
        end
      end
    end

    it "resolves explicit and inherited access controls for preparation" do
      allow(Aws::S3::Client).to receive(:new).and_return(client)
      allow(SiteSetting).to receive(:s3_use_acls).and_return(true)
      allow(SiteSetting).to receive(:s3_enable_access_control_tags).and_return(false)
      configuration = BulkImport::DiscourseMerge::Configuration.new(".", contents: project.to_yaml)
      [
        [{}, [true, false]],
        [{ s3_enable_access_control_tags: true }, [false, true]],
        [{ s3_use_acls: true, s3_enable_access_control_tags: true }, [true, true]],
        [{ s3_use_acls: false, s3_enable_access_control_tags: false }, [false, false]],
        [{ s3_enable_access_control_tags: false }, [true, false]],
      ].each do |overrides, policy|
        input = uploader.deep_symbolize_keys
        input[:site_settings] = settings.except(:s3_use_acls, :s3_enable_access_control_tags).merge(
          overrides,
        )
        output = StringIO.new
        store =
          described_class.for_preparation(
            configuration,
            input,
            BulkImport::DiscourseMerge::Progress.new(output: output),
          )
        expect(store.target.fetch("access").take(2)).to eq(policy)
        expect(output.string).to include("ACLs=#{policy.first}, access-control tags=#{policy.last}")
      end
    end
  end

  it "checks the configured bucket and addresses the same folder and tenant as Discourse" do
    client.stub_responses(:head_bucket, { bucket_region: "us-west-2" })
    store.check!
    expect(client.api_requests.last[:params][:bucket]).to eq("shared")
    expect(store.object(file_key)).to eq(bucket: "shared", key: "sites/uploads/target/#{file_key}")
    expect(store.location(file_key)).to eq(
      "//shared.s3.dualstack.us-west-2.amazonaws.com/sites/uploads/target/#{file_key}",
    )
    expect(store.target.to_s).not_to include("test-secret", "test-key")
    client.stub_responses(:head_bucket, { bucket_region: "eu-west-1" })
    expect { store.check! }.to raise_error(ArgumentError, /region/)
  end

  it "checks only the configured target prefix when the bucket check is denied" do
    client.stub_responses(:head_bucket, "Forbidden")
    client.stub_responses(:list_objects_v2, contents: [])

    store.check!

    expect(client.api_requests.last).to include(
      operation_name: :list_objects_v2,
      params: {
        bucket: "shared",
        prefix: "sites/uploads/target/",
        max_keys: 1,
      },
    )
    client.stub_responses(:list_objects_v2, "AccessDenied")
    expect { store.check! }.to raise_error(Aws::S3::Errors::AccessDenied)
  end

  it "conditionally creates the native bytes with the checksum and privacy tag" do
    Tempfile.create(%w[original .pdf]) do |file|
      file.write("test")
      file.flush
      store.create(
        store.object(file_key),
        Pathname(file.path),
        "document.pdf",
        true,
        Digest::SHA256.hexdigest("test"),
      )
      request = client.api_requests.last
      expect(request[:operation_name]).to eq(:put_object)
      expect(request[:params]).to include(
        bucket: "shared",
        key: "sites/uploads/target/#{file_key}",
        if_none_match: "*",
        checksum_sha256: Digest::SHA256.base64digest("test"),
        tagging: "discourse%3Aacl=private",
        content_type: "application/pdf",
      )
      client.stub_responses(:put_object, "PreconditionFailed")
      expect(
        store.create(
          store.object(file_key),
          Pathname(file.path),
          "document.pdf",
          true,
          Digest::SHA256.hexdigest("test"),
        ),
      ).to be_nil
    end
  end

  it "only reads an additional input bucket under the configured prefix" do
    store =
      described_class.new(
        settings,
        client: client,
        read_prefixes: {
          source: "s3://old/uploads/tenant",
        },
      )
    client.stub_responses(
      :get_object_tagging,
      { tag_set: [{ key: "discourse:acl", value: "private" }] },
    )
    client.stub_responses(:get_object, { body: "private bytes" })
    read = +""
    expect(
      store.read_backup(store.target.dig("read_prefixes", "source"), file_key, true) do |chunk|
        read << chunk
      end,
    ).to eq(true)
    expect(read).to eq("private bytes")
    expect(client.api_requests.map { |req| req[:params].slice(:bucket, :key) }.uniq).to eq(
      [{ bucket: "old", key: "uploads/tenant/#{file_key}" }],
    )
  end

  it "conditionally completes multipart uploads and aborts a losing write" do
    Tempfile.create(%w[large .pdf]) do |file|
      file.truncate(65.megabytes)
      path = Pathname(file.path)
      params = store.object(file_key)
      client.stub_responses(:create_multipart_upload, upload_id: "multipart")
      client.stub_responses(:upload_part, etag: "part")
      client.stub_responses(:complete_multipart_upload, "PreconditionFailed")
      expect(
        store.create(params, path, "large.pdf", false, Digest::SHA256.file(path).hexdigest),
      ).to be_nil
      operations = client.api_requests.group_by { |r| r[:operation_name] }
      expect(operations[:upload_part].size).to eq(5)
      expect(operations[:complete_multipart_upload].first[:params]).to include(if_none_match: "*")
      expect(operations[:abort_multipart_upload].first[:params]).to include(
        params.merge(upload_id: "multipart"),
      )
    end
  end

  it "checks the hosted visibility of retained objects and distinguishes missing keys from denied access" do
    params = store.object(file_key)
    client.stub_responses(
      :get_object_tagging,
      { tag_set: [{ key: "discourse:acl", value: "public" }] },
    )
    expect { store.check_access!(params, true) }.to raise_error(/access tag differs/)
    expect { store.check_access!(params, false) }.not_to raise_error
    client.stub_responses(:head_object, "NotFound")
    expect(store.head(params)).to be_nil
    client.stub_responses(:head_object, "AccessDenied")
    client.stub_responses(:list_objects_v2, contents: [{ key: params.fetch(:key) }])
    expect { store.head(params) }.to raise_error(Aws::S3::Errors::AccessDenied)
  end

  it "uses a paginated listing to distinguish absence when individual HEAD requests return 403" do
    params = store.object(file_key)
    client.stub_responses(:head_object, "Forbidden")
    client.stub_responses(
      :list_objects_v2,
      [
        {
          contents: [{ key: "#{params.fetch(:key)}.bak" }],
          is_truncated: true,
          next_continuation_token: "next",
        },
        { contents: [{ key: store.object("original/1X/existing.pdf").fetch(:key) }] },
      ],
    )

    expect(store.head(params)).to be_nil
    expect { store.head(store.object("original/1X/existing.pdf")) }.to raise_error(
      Aws::S3::Errors::Forbidden,
    )
    expect { store.head(params, known_present: true) }.to raise_error(Aws::S3::Errors::Forbidden)
    expect(
      client.api_requests.filter_map do |request|
        request.fetch(:params) if request.fetch(:operation_name) == :list_objects_v2
      end,
    ).to eq(
      [
        { bucket: "shared", prefix: "sites/uploads/target/" },
        { bucket: "shared", prefix: "sites/uploads/target/", continuation_token: "next" },
      ],
    )
  end

  it "checks missing backup objects within their configured read prefix" do
    store =
      described_class.new(
        settings,
        client: client,
        read_prefixes: {
          destination: "s3://old/production-tenant",
        },
      )
    client.stub_responses(:head_object, "Forbidden")
    client.stub_responses(:list_objects_v2, contents: [])

    expect(store.read_backup("s3://old/production-tenant", file_key, false)).to be(false)
    expect(client.api_requests.last).to include(
      operation_name: :list_objects_v2,
      params: {
        bucket: "old",
        prefix: "production-tenant/",
      },
    )
    expect { store.head({ bucket: "old", key: "another/#{file_key}" }) }.to raise_error(
      Aws::S3::Errors::Forbidden,
    )
  end
end
