# frozen_string_literal: true

require "file_store/s3_store"

RSpec.describe FileStore::ObjectStorage::S3 do
  let(:endpoint) { "https://storage.example.test" }
  let(:client) do
    Aws::S3::Client.new(
      endpoint: endpoint,
      region: "us-east-1",
      credentials: Aws::Credentials.new("test", "test"),
      force_path_style: true,
      retry_limit: 0,
    )
  end
  let(:bucket) { Aws::S3::Resource.new(client:).bucket("uploads") }
  let(:helper) { S3Helper.new("uploads", "", client:, bucket:) }
  let(:provider) { described_class.new(helper) }

  before do
    setup_s3
    SiteSetting.s3_endpoint = endpoint
  end

  def storage_operations(adapter, file)
    {
      upload: -> { adapter.upload(file, "file", visibility: :private) },
      put: -> { adapter.put(file, "file", visibility: :private) },
      upload_file: -> { adapter.upload_file("file", file.path, visibility: :private) },
      copy: -> { adapter.copy("file", "copy", visibility: :private) },
      delete: -> { adapter.delete("file") },
      remove: -> { adapter.remove("file") },
      download: -> { adapter.download("file", "#{file.path}.download") },
      stat: -> { adapter.stat("file") },
      list: -> { adapter.list.to_a },
      set_visibility: -> { adapter.set_visibility("file", visibility: :private) },
      create_multipart: -> { adapter.create_multipart("file", "text/plain", visibility: :private) },
      list_multipart_parts: -> { adapter.list_multipart_parts(upload_id: "session", key: "file") },
      complete_multipart: -> do
        adapter.complete_multipart(
          upload_id: "session",
          key: "file",
          parts: [{ part_number: 1, etag: "part" }],
        )
      end,
      abort_multipart: -> { adapter.abort_multipart(upload_id: "session", key: "file") },
    }
  end

  it "normalizes transport timeouts across network operations without treating them as missing objects" do
    stub_request(:any, %r{\A#{Regexp.escape(endpoint)}/}).to_timeout
    Tempfile.create do |file|
      file.write("bytes")
      file.flush
      storage_operations(provider, file).each do |name, operation|
        aggregate_failures(name) do
          expect(&operation).to raise_error(FileStore::ObjectStorage::ConnectionError) do |error|
            expect(error.cause).to be_a(Seahorse::Client::NetworkingError)
            # Callers rescuing service refusals must not swallow an outage.
            expect(error).not_to be_a(FileStore::ObjectStorage::ServiceError)
          end
        end
      end
    end
  end

  it "normalizes missing credentials across network operations without contacting storage" do
    unsigned_client =
      Aws::S3::Client.new(
        endpoint:,
        region: "us-east-1",
        credentials: Aws::Credentials.new(nil, nil),
        force_path_style: true,
        retry_limit: 0,
      )
    unsigned = described_class.new(S3Helper.new("uploads", "", client: unsigned_client))
    Tempfile.create do |file|
      file.write("bytes")
      file.flush
      storage_operations(unsigned, file).each do |name, operation|
        aggregate_failures(name) do
          expect(&operation).to raise_error(
            FileStore::ObjectStorage::CredentialsUnavailable,
          ) do |error|
            expect(error.cause).to be_a(Aws::Errors::MissingCredentialsError).or(
              be_a(Aws::Sigv4::Errors::MissingCredentialsError),
            )
            expect(error).not_to be_a(FileStore::ObjectStorage::ServiceError)
          end
        end
      end
    end
  end

  it "changes visibility using provider ACLs" do
    %i[public private].each do |visibility|
      request =
        stub_request(:put, "#{endpoint}/uploads/image.png?acl").with(
          headers: {
            "x-amz-acl" => visibility == :private ? "private" : "public-read",
          },
        ).to_return(status: 200)
      provider.set_visibility("image.png", visibility:)
      expect(request).to have_been_requested.once
    end
  end

  it "updates the visibility tag without removing unrelated tags" do
    SiteSetting.s3_use_acls = false
    SiteSetting.s3_enable_access_control_tags = true
    SiteSetting.s3_access_control_tag_key = "visibility"
    SiteSetting.s3_access_control_tag_private_value = "private"
    stub_request(:get, "#{endpoint}/uploads/image.png?tagging").to_return(
      status: 200,
      body:
        "<Tagging><TagSet><Tag><Key>owner</Key><Value>site</Value></Tag><Tag><Key>visibility</Key><Value>public</Value></Tag></TagSet></Tagging>",
    )
    request =
      stub_request(:put, "#{endpoint}/uploads/image.png?tagging")
        .with do |req|
          tags = Hash.from_xml(req.body).dig("Tagging", "TagSet", "Tag")
          tags.to_h { |tag| [tag["Key"], tag["Value"]] } ==
            { "owner" => "site", "visibility" => "private" }
        end
        .to_return(status: 200)
    provider.set_visibility("image.png", visibility: :private)
    expect(request).to have_been_requested.once
  end

  it "keeps the legacy warning behavior for unsupported ACL updates" do
    stub_request(:put, "#{endpoint}/uploads/image.png?acl").to_return(
      status: 501,
      body: "<Error><Code>NotImplemented</Code></Error>",
    )
    Discourse
      .expects(:warn_exception)
      .with do |error, **opts|
        error.is_a?(Aws::S3::Errors::NotImplemented) &&
          opts[:message].include?("does not support setting ACLs")
      end
    expect { provider.set_visibility("image.png", visibility: :private) }.not_to raise_error
  end

  it "keeps missing-object warnings distinct from denied permission changes" do
    stub_request(:put, "#{endpoint}/uploads/missing?acl").to_return(
      status: 404,
      body: "<Error><Code>NoSuchKey</Code></Error>",
    )
    Rails.logger.expects(:warn).with(includes("Upload is missing"))
    provider.set_visibility("missing", visibility: :private)
    stub_request(:put, "#{endpoint}/uploads/denied?acl").to_return(
      status: 403,
      body: "<Error><Code>AccessDenied</Code></Error>",
    )
    expect { provider.set_visibility("denied", visibility: :private) }.to raise_error(
      FileStore::ObjectStorage::AccessDenied,
    )
  end

  it "propagates normalized tag failures after an unsupported ACL warning" do
    SiteSetting.s3_enable_access_control_tags = true
    SiteSetting.s3_access_control_tag_key = "visibility"
    stub_request(:put, "#{endpoint}/uploads/image.png?acl").to_return(
      status: 501,
      body: "<Error><Code>NotImplemented</Code></Error>",
    )
    stub_request(:get, "#{endpoint}/uploads/image.png?tagging").to_return(
      status: 403,
      body: "<Error><Code>AccessDenied</Code></Error>",
    )
    Discourse.expects(:warn_exception).with(instance_of(Aws::S3::Errors::NotImplemented), anything)
    expect { provider.set_visibility("image.png", visibility: :private) }.to raise_error(
      FileStore::ObjectStorage::AccessDenied,
    ) do |error|
      expect(error.cause).to be_a(Aws::S3::Errors::AccessDenied)
    end
  end

  it "normalizes missing signing credentials without changing argument validation" do
    unsigned_client =
      Aws::S3::Client.new(
        endpoint:,
        region: "us-east-1",
        credentials: Aws::Credentials.new(nil, nil),
        force_path_style: true,
      )
    unsigned = described_class.new(S3Helper.new("uploads", "", client: unsigned_client))
    operations = [
      -> { unsigned.upload_url("file", expires_in: 60) },
      -> { unsigned.download_url("file", expires_in: 60) },
      -> { unsigned.upload_request("file", visibility: :private, expires_in: 60) },
      -> { unsigned.presign_multipart_part(upload_id: "session", key: "file", part_number: 1) },
    ]
    operations.each do |operation|
      expect(&operation).to raise_error(FileStore::ObjectStorage::CredentialsUnavailable) do |error|
        expect(error.cause).to be_a(Aws::Errors::MissingCredentialsError).or(
          be_a(Aws::Sigv4::Errors::MissingCredentialsError),
        )
      end
    end
    expect { provider.download_url("file", expires_in: -1) }.to raise_error(ArgumentError)
  end

  {
    "AccessDenied" => [403, Aws::S3::Errors::AccessDenied, "due to permissions"],
    "InternalError" => [500, Aws::S3::Errors::InternalError, "with AWS error"],
  }.each do |code, (status, error_class, message)|
    it "retains MediaConvert diagnostics for #{code} through the file-store boundary" do
      stub_request(:put, "#{endpoint}/uploads/video.mp4?acl").to_return(
        status:,
        body: "<Error><Code>#{code}</Code></Error>",
      )
      upload = Upload.new(id: 123, secure: true)
      converter = VideoConversion::AwsMediaConvertAdapter.new(upload)
      store = FileStore::S3Store.new(helper, object_storage: provider)
      Discourse
        .expects(:warn_exception)
        .with do |error, **opts|
          error.is_a?(error_class) && opts[:message].include?(message) &&
            opts[:env][:upload_id] == upload.id &&
            (code != "InternalError" || opts[:env][:error_code] == code)
        end
      expect { converter.send(:update_file_acl, store, "video.mp4") }.to raise_error(error_class)
    end
  end

  %i[file upload optimized_image].each do |target|
    {
      "AccessDenied" => [
        403,
        Aws::S3::Errors::AccessDenied,
        FileStore::ObjectStorage::AccessDenied,
      ],
      "NotFound" => [404, Aws::S3::Errors::NotFound, FileStore::ObjectStorage::ObjectNotFound],
      "InternalError" => [500, Aws::S3::Errors::InternalError, FileStore::ObjectStorage::Error],
    }.each do |code, (status, sdk_error, storage_error)|
      it "preserves #{code} at the #{target} permission API without changing adapter errors" do
        store = FileStore::S3Store.new(helper, object_storage: provider)
        upload = Upload.new(id: 123, sha1: "a" * 40, original_filename: "image.png", secure: true)
        optimized =
          OptimizedImage.new(upload:, width: 100, height: 100, extension: ".png", version: 1)
        key =
          case target
          when :file
            "image.png"
          when :upload
            store.get_path_for_upload(upload)
          else
            store.get_path_for_optimized_image(optimized)
          end
        request =
          stub_request(:put, "#{endpoint}/uploads/#{key}?acl").to_return(
            status:,
            body: "<Error><Code>#{code}</Code></Error>",
          )

        expect {
          case target
          when :file
            store.update_file_access_control(key, true)
          when :upload
            store.update_upload_access_control(upload)
          else
            store.update_optimized_image_access_control(optimized, secure: true)
          end
        }.to raise_error(sdk_error) do |error|
          expect(error.code).to eq(code)
          expect(error.context.operation_name).to eq(:put_object_acl)
          expect(error.cause).not_to be_a(FileStore::ObjectStorage::Error)
        end
        expect { provider.set_visibility(key, visibility: :private) }.to raise_error(
          storage_error,
        ) do |error|
          expect(error.cause).to be_a(sdk_error)
        end
        expect(request).to have_been_requested.twice
      end
    end
  end

  [false, true].each do |cleanup_failure|
    it "completes video storage and persists metadata with cleanup_failure=#{cleanup_failure}" do
      SiteSetting.authorized_extensions = "mp4"
      SiteSetting.mediaconvert_output_subdirectory = "transcoded"
      upload = Fabricate(:video_upload, secure: cleanup_failure)
      checksum = "b" * 40
      store = FileStore::S3Store.new(helper)
      key = store.get_path_for_upload(Upload.new(id: upload.id, sha1: checksum, extension: "mp4"))
      temporary_key = "transcoded/#{checksum}.mp4"
      FileStore::S3Store.stubs(:new).returns(store)
      Discourse.stubs(:store).returns(store)
      stub_request(:head, %r{\A#{Regexp.escape(endpoint)}/uploads/}).to_return(
        status: 200,
        headers: {
          "Content-Length" => "5",
          "ETag" => '"converted"',
        },
      )
      acl = cleanup_failure ? "private" : "public-read"
      copy =
        stub_request(:put, "#{endpoint}/uploads/#{key}").with(
          headers: {
            "X-Amz-Copy-Source" => "uploads/#{temporary_key}",
            "X-Amz-Acl" => acl,
          },
        ).to_return(
          status: 200,
          body: '<CopyObjectResult><ETag>"converted"</ETag></CopyObjectResult>',
        )
      permissions =
        stub_request(:put, "#{endpoint}/uploads/#{key}?acl").with(
          headers: {
            "X-Amz-Acl" => acl,
          },
        ).to_return(status: 200)
      cleanup =
        stub_request(:delete, "#{endpoint}/uploads/#{temporary_key}").to_return(
          status: cleanup_failure ? 403 : 204,
          body: cleanup_failure ? "<Error><Code>AccessDenied</Code></Error>" : "",
        )

      converter = VideoConversion::AwsMediaConvertAdapter.new(upload)
      expect(converter.handle_completion("job", checksum)).to eq(true)
      optimized = OptimizedVideo.find_by!(upload_id: upload.id).optimized_upload
      expect(optimized.attributes.slice("sha1", "etag", "filesize", "secure")).to eq(
        "sha1" => checksum,
        "etag" => "converted",
        "filesize" => 5,
        "secure" => cleanup_failure,
      )
      expect(copy).to have_been_requested.once
      expect(permissions).to have_been_requested.once
      expect(cleanup).to have_been_requested.once
    end
  end

  %i[file upload optimized_image].each do |target|
    %i[network credentials].each do |failure|
      it "preserves #{failure} errors at the #{target} permission API" do
        permission_client =
          if failure == :credentials
            Aws::S3::Client.new(
              endpoint: endpoint,
              region: "us-east-1",
              credentials: Aws::Credentials.new(nil, nil),
              force_path_style: true,
              retry_limit: 0,
            )
          else
            client
          end
        permission_bucket = Aws::S3::Resource.new(client: permission_client).bucket("uploads")
        permission_helper =
          S3Helper.new("uploads", "", client: permission_client, bucket: permission_bucket)
        store = FileStore::S3Store.new(permission_helper)
        request = stub_request(:put, %r{\A#{Regexp.escape(endpoint)}/uploads/.*\?acl\z}).to_timeout
        upload = Upload.new(id: 123, sha1: "a" * 40, original_filename: "image.png", secure: true)
        optimized =
          OptimizedImage.new(upload:, width: 100, height: 100, extension: ".png", version: 1)

        expect {
          case target
          when :file
            store.update_file_access_control("image.png", true)
          when :upload
            store.update_upload_access_control(upload)
          else
            store.update_optimized_image_access_control(optimized, secure: true)
          end
        }.to raise_error do |error|
          if failure == :network
            expect(error).to be_a(Seahorse::Client::NetworkingError)
            expect(error.original_error).to be_a(Timeout::Error)
            expect(error.cause).to be_nil
          else
            expect(error).to be_a(Aws::Errors::MissingCredentialsError).or(
              be_a(Aws::Sigv4::Errors::MissingCredentialsError),
            )
          end
          expect(error.cause).not_to be_a(FileStore::ObjectStorage::Error)
        end

        if failure == :network
          expect(request).to have_been_requested.once
        else
          expect(request).not_to have_been_requested
        end
      end
    end
  end

  it "does not classify unrelated error causes as SDK failures" do
    expect(described_class.sdk_error?(nil)).to eq(false)
    expect(described_class.sdk_error?(IOError.new("local failure"))).to eq(false)
    expect(
      described_class.sdk_error?(FileStore::ObjectStorage::Error.new("provider failure")),
    ).to eq(false)
  end

  %i[upload copy delete remove avatar].each do |operation|
    %i[service network].each do |failure|
      it "preserves #{failure} errors from the legacy #{operation} store API" do
        SiteSetting.s3_upload_bucket = "uploads"
        store = FileStore::S3Store.new(S3Helper.new("uploads", "tombstone/", client:, bucket:))
        request = stub_request(:any, %r{\A#{Regexp.escape(endpoint)}/uploads/})
        if failure == :network
          request.to_timeout
        else
          request.to_return(status: 403, body: "<Error><Code>AccessDenied</Code></Error>")
        end
        avatar =
          OptimizedImage.new(
            upload_id: 42,
            width: 120,
            url: "#{store.absolute_base_url}/avatar.png",
          )

        Tempfile.create do |file|
          file.write("bytes")
          file.rewind
          expect {
            case operation
            when :upload
              store.store_file(file, "file.png")
            when :copy
              store.copy_file(source: "file.png", destination: "copy.png", secure: false)
            when :delete
              store.delete_file("file.png")
            when :remove
              store.remove_file("#{store.absolute_base_url}/file.png", "file.png")
            when :avatar
              store.cache_avatar(avatar, 123)
            end
          }.to raise_error do |error|
            if failure == :network
              expect(error).to be_a(Seahorse::Client::NetworkingError)
              expect(error.original_error).to be_a(Timeout::Error)
            else
              expect(error).to be_a(Aws::S3::Errors::ServiceError)
              expect(error.context.http_response.status_code).to eq(403)
            end
            expect(error.cause).not_to be_a(FileStore::ObjectStorage::Error)
          end
        end
        expect(request).to have_been_requested.once
      end
    end
  end

  it "does not unwrap an unrelated cause from an injected provider's upload error" do
    storage_error = FileStore::ObjectStorage::Error.new("provider failure")
    local_error = IOError.new("local cause")
    adapter = Object.new
    adapter.define_singleton_method(:upload) { |*| raise storage_error, cause: local_error }
    store = FileStore::S3Store.new(object_storage: adapter)

    expect { store.store_file(nil, "file.png") }.to raise_error(
      FileStore::ObjectStorage::Error,
    ) do |error|
      expect(error).to equal(storage_error)
      expect(error.cause).to equal(local_error)
    end
  end

  %i[file upload delete promote].each do |operation|
    %i[service network].each do |failure|
      it "preserves #{failure} errors from the backup #{operation} API" do
        SiteSetting.s3_backup_bucket = "uploads/site"
        store = BackupRestore::S3BackupStore.new(s3_options: { client:, bucket: })
        key = "site/#{RailsMultisite::ConnectionManagement.current_db}/backup.tar.gz"
        method = { file: :head, upload: :put, delete: :delete, promote: :put }.fetch(operation)
        request = stub_request(method, "#{endpoint}/uploads/#{key}")
        if failure == :network
          request.to_timeout
        else
          request.to_return(status: 403, body: "<Error><Code>AccessDenied</Code></Error>")
        end

        if operation == :upload
          stub_request(:head, "#{endpoint}/uploads/#{key}").to_return(status: 404)
        elsif operation == :delete || operation == :promote
          source = operation == :promote ? "temp/backup.tar.gz" : key
          stub_request(:head, "#{endpoint}/uploads/#{source}").to_return(
            status: 200,
            headers: {
              "Content-Length" => "5",
              "Last-Modified" => Time.now.httpdate,
            },
          )
        end

        Tempfile.create do |file|
          file.write("bytes")
          file.flush
          expect {
            case operation
            when :file
              store.file("backup.tar.gz")
            when :upload
              store.upload_file("backup.tar.gz", file.path, "application/gzip")
            when :delete
              store.delete_file("backup.tar.gz")
            when :promote
              store.move_existing_stored_upload(
                existing_external_upload_key: "temp/backup.tar.gz",
                original_filename: "backup.tar.gz",
              )
            end
          }.to raise_error do |error|
            if failure == :network
              expect(error).to be_a(Seahorse::Client::NetworkingError)
              expect(error.original_error).to be_a(Timeout::Error)
            else
              expect(error).to be_a(Aws::S3::Errors::ServiceError)
              expect(error.context.http_response.status_code).to eq(403)
            end
            expect(error.cause).not_to be_a(FileStore::ObjectStorage::Error)
          end
        end
        expect(request).to have_been_requested.once
      end
    end
  end

  %i[listing upload_url].each do |operation|
    %i[service network credentials].each do |failure|
      it "preserves the backup #{operation} wrapper for #{failure} errors" do
        SiteSetting.s3_backup_bucket = "uploads/site"
        backup_client =
          if failure == :credentials
            Aws::S3::Client.new(
              endpoint: endpoint,
              region: "us-east-1",
              credentials: Aws::Credentials.new(nil, nil),
              force_path_style: true,
              retry_limit: 0,
            )
          else
            client
          end
        backup_bucket = Aws::S3::Resource.new(client: backup_client).bucket("uploads")
        store =
          BackupRestore::S3BackupStore.new(
            s3_options: {
              client: backup_client,
              bucket: backup_bucket,
            },
          )
        request = stub_request(:any, %r{\A#{Regexp.escape(endpoint)}/uploads})
        if failure == :network
          request.to_timeout
        else
          request.to_return(status: 403, body: "<Error><Code>AccessDenied</Code></Error>")
        end

        expect {
          operation == :listing ? store.files : store.generate_upload_url("backup.tar.gz")
        }.to raise_error do |error|
          case failure
          when :service
            expect(error).to be_a(BackupRestore::BackupStore::StorageError)
            expect(error.cause).to be_a(Aws::S3::Errors::ServiceError)
            expect(error.message).to eq(error.cause.message.presence || error.cause.class.name)
            expect(error.cause.context.http_response.status_code).to eq(403)
          when :network
            expect(error).to be_a(Seahorse::Client::NetworkingError)
            expect(error.original_error).to be_a(Timeout::Error)
          when :credentials
            expect(error).to be_a(Aws::Errors::MissingCredentialsError).or(
              be_a(Aws::Sigv4::Errors::MissingCredentialsError),
            )
          end
          expect(error.cause).not_to be_a(FileStore::ObjectStorage::Error)
        end

        if failure == :credentials
          expect(request).not_to have_been_requested
        else
          expect(request).to have_been_requested.once
        end
      end
    end
  end

  it "requires explicit visibility when changing permissions" do
    expect { provider.set_visibility("image.png", visibility: :bucket_default) }.to raise_error(
      ArgumentError,
    )
    expect { provider.set_visibility("image.png", visibility: :unknown) }.to raise_error(
      ArgumentError,
    )
  end

  it "preserves SDK credential errors for legacy upload and download signing" do
    unsigned_client =
      Aws::S3::Client.new(
        endpoint:,
        region: "us-east-1",
        credentials: Aws::Credentials.new(nil, nil),
        force_path_style: true,
        retry_limit: 0,
      )
    store = FileStore::S3Store.new(S3Helper.new("uploads", "", client: unsigned_client))
    operations = [
      -> { store.signed_request_for_temporary_upload("file.txt") },
      -> { store.signed_url_for_path("file.txt", include_content_disposition: true) },
    ]

    operations.each do |operation|
      expect(&operation).to raise_error do |error|
        expect(error).to be_a(Aws::Errors::MissingCredentialsError).or(
          be_a(Aws::Sigv4::Errors::MissingCredentialsError),
        )
        expect(error.cause).not_to be_a(FileStore::ObjectStorage::Error)
      end
    end
    expect { store.prepare_direct_upload("file.txt") }.to raise_error(
      FileStore::ObjectStorage::CredentialsUnavailable,
    )
  end

  it "preserves signing argument errors at the legacy store boundary" do
    store = FileStore::S3Store.new(helper)
    expect { store.signed_request_for_temporary_upload("file.txt", expires_in: -1) }.to raise_error(
      ArgumentError,
    )
    expect {
      store.signed_url_for_path("file.txt", expires_in: -1, include_content_disposition: true)
    }.to raise_error(ArgumentError)
  end

  %i[uploads backups].each do |storage_type|
    %i[service network].each do |failure|
      it "preserves #{failure} errors for legacy #{storage_type} multipart creation" do
        store =
          if storage_type == :backups
            SiteSetting.s3_backup_bucket = "uploads"
            BackupRestore::S3BackupStore.new(s3_options: { client:, bucket: })
          else
            FileStore::S3Store.new(helper)
          end
        stub_request(:head, %r{\A#{Regexp.escape(endpoint)}/uploads/}).to_return(status: 404)
        request = stub_request(:post, %r{\A#{Regexp.escape(endpoint)}/uploads/})
        if failure == :network
          request.to_timeout
        else
          request.to_return(status: 403, body: "<Error><Code>AccessDenied</Code></Error>")
        end

        expect { store.create_multipart("file.txt", "text/plain") }.to raise_error do |error|
          if failure == :network
            expect(error).to be_a(Seahorse::Client::NetworkingError)
            expect(error.original_error).to be_a(Timeout::Error)
          else
            expect(error).to be_a(Aws::S3::Errors::AccessDenied)
            expect(error.context.http_response.status_code).to eq(403)
          end
          expect(error.cause).not_to be_a(FileStore::ObjectStorage::Error)
        end
        expected_error =
          (
            if failure == :network
              FileStore::ObjectStorage::ConnectionError
            else
              FileStore::ObjectStorage::AccessDenied
            end
          )
        expect { store.prepare_multipart_upload("file.txt", "text/plain") }.to raise_error(
          expected_error,
        )
      end
    end
  end

  it "returns object metadata without exposing the SDK object" do
    stub_request(:head, "#{endpoint}/uploads/image.png").to_return(
      status: 200,
      headers: {
        "Content-Length" => "12",
        "ETag" => '"opaque"',
        "Last-Modified" => "Sun, 04 Oct 2026 00:00:00 GMT",
        "x-amz-meta-sha1-checksum" => "digest",
      },
    )
    info = provider.stat("image.png")
    expect(info).to be_a(FileStore::ObjectStorage::ObjectInfo)
    expect(info.key).to eq("image.png")
    expect(info.size).to eq(12)
    expect(info.etag).to eq('"opaque"')
    expect(info.last_modified).to eq(Time.utc(2026, 10, 4))
    expect(info.metadata).to eq("sha1-checksum" => "digest")
  end

  it "distinguishes missing objects from denied access" do
    stub_request(:head, "#{endpoint}/uploads/missing").to_return(status: 404)
    stub_request(:head, "#{endpoint}/uploads/denied").to_return(status: 403)
    expect(provider.stat("missing")).to be_nil
    expect { provider.stat("denied") }.to raise_error(
      FileStore::ObjectStorage::AccessDenied,
    ) do |error|
      expect(error.cause).to be_a(Aws::S3::Errors::Forbidden)
    end
  end

  it "inspects an object with a single request" do
    request =
      stub_request(:head, "#{endpoint}/uploads/image.png").to_return(
        status: 200,
        headers: {
          "Content-Length" => "1",
          "x-amz-meta-sha1-checksum" => "digest",
        },
      )
    info = provider.stat("image.png")
    expect(info.metadata).to eq("sha1-checksum" => "digest")
    expect(request).to have_been_requested.once
  end

  it "does not treat a failed inspection as an absent object" do
    stub_request(:head, "#{endpoint}/uploads/unavailable").to_return(status: 500)
    expect { provider.stat("unavailable") }.to raise_error(
      FileStore::ObjectStorage::ServiceError,
    ) do |error|
      expect(error.cause).to be_a(Aws::S3::Errors::ServiceError)
    end
  end

  it "normalizes errors fetching later listing pages without eagerly fetching them" do
    first =
      stub_request(:get, "#{endpoint}/uploads").with(
        query: {
          "list-type" => "2",
          "prefix" => "original/",
        },
      ).to_return(
        status: 200,
        body:
          "<ListBucketResult><IsTruncated>true</IsTruncated><NextContinuationToken>next</NextContinuationToken><Contents><Key>original/a</Key><Size>1</Size></Contents></ListBucketResult>",
      )
    second =
      stub_request(:get, "#{endpoint}/uploads").with(
        query: {
          "list-type" => "2",
          "prefix" => "original/",
          "continuation-token" => "next",
        },
      ).to_return(
        status: 403,
        body: "<Error><Code>AccessDenied</Code><Message>listing denied</Message></Error>",
      )
    objects = provider.list("original/")
    expect(first).not_to have_been_requested
    expect(objects.next.key).to eq("original/a")
    expect(second).not_to have_been_requested
    expect { objects.next }.to raise_error(
      FileStore::ObjectStorage::AccessDenied,
      "listing denied",
    ) do |error|
      expect(error.cause).to be_a(Aws::S3::Errors::AccessDenied)
    end
    expect(first).to have_been_requested.once
    expect(second).to have_been_requested.once
  end

  it "retries a single PUT without oversized disposition metadata while preserving bytes and checksum" do
    bytes = "migration bytes"
    checksum = Digest::MD5.base64digest(bytes)
    first =
      stub_request(:put, "#{endpoint}/uploads/original/file.txt").with(
        body: bytes,
        headers: {
          "Content-Md5" => checksum,
          "Content-Disposition" => "attachment",
          "X-Amz-Acl" => "private",
        },
      ).to_return(status: 400, body: "<Error><Code>MetadataTooLarge</Code></Error>")
    second =
      stub_request(:put, "#{endpoint}/uploads/original/file.txt")
        .with(
          body: bytes,
          headers: {
            "Content-Md5" => checksum,
            "X-Amz-Acl" => "private",
          },
        ) { |request| !request.headers.key?("Content-Disposition") }
        .to_return(status: 200, headers: { "ETag" => '"opaque"' })
    Tempfile.create do |file|
      file.write(bytes)
      file.rewind
      result =
        provider.put(
          file,
          "original/file.txt",
          visibility: :private,
          headers: {
            content_disposition: "attachment",
            content_type: "text/plain",
          },
          content_md5: checksum,
        )
      expect(result).to eq(
        FileStore::ObjectStorage::Result.new(key: "original/file.txt", etag: '"opaque"'),
      )
    end
    expect(first).to have_been_requested.once
    expect(second).to have_been_requested.once
  end

  it "stops retrying a single PUT when removing disposition does not fix metadata rejection" do
    request =
      stub_request(:put, "#{endpoint}/uploads/file").to_return(
        status: 400,
        body: "<Error><Code>MetadataTooLarge</Code></Error>",
      )
    Tempfile.create do |file|
      expect {
        provider.put(
          file,
          "file",
          visibility: :public,
          headers: {
            content_disposition: "attachment",
          },
        )
      }.to raise_error(FileStore::ObjectStorage::Error) do |error|
        expect(error.cause).to be_a(Aws::S3::Errors::MetadataTooLarge)
      end
    end
    expect(request).to have_been_requested.twice
  end

  it "reports a missing listing bucket as a service failure, not an empty listing" do
    stub_request(:get, "#{endpoint}/uploads").with(
      query: {
        "list-type" => "2",
        "prefix" => "",
      },
    ).to_return(status: 404, body: "<Error><Code>NoSuchBucket</Code></Error>")
    expect { provider.list.to_a }.to raise_error(FileStore::ObjectStorage::Error) do |error|
      expect(error.class).to eq(FileStore::ObjectStorage::ServiceError)
      expect(error.cause).to be_a(Aws::S3::Errors::NoSuchBucket)
    end
  end

  %i[first later].each do |page|
    %i[service network].each do |failure|
      it "preserves legacy #{failure} errors on the #{page} missing-upload listing page and cleans up" do
        SiteSetting.stubs(:s3_inventory_bucket).returns(nil)
        store = FileStore::S3Store.new(helper)
        query = { "list-type" => "2", "prefix" => "original/" }
        if page == :later
          stub_request(:get, "#{endpoint}/uploads").with(query: query).to_return(
            status: 200,
            body:
              "<ListBucketResult><IsTruncated>true</IsTruncated><NextContinuationToken>next</NextContinuationToken><Contents><Key>original/a</Key><Size>1</Size></Contents></ListBucketResult>",
          )
          query = query.merge("continuation-token" => "next")
        end
        request = stub_request(:get, "#{endpoint}/uploads").with(query: query)
        if failure == :network
          request.to_timeout
        else
          request.to_return(status: 403, body: "<Error><Code>AccessDenied</Code></Error>")
        end

        expect { store.list_missing_uploads(skip_optimized: true) }.to raise_error do |error|
          if failure == :network
            expect(error).to be_a(Seahorse::Client::NetworkingError)
            expect(error.original_error).to be_a(Timeout::Error)
          else
            expect(error).to be_a(Aws::S3::Errors::AccessDenied)
            expect(error.context.http_response.status_code).to eq(403)
          end
          expect(error.cause).not_to be_a(FileStore::ObjectStorage::Error)
        end
        expect(request).to have_been_requested.once
        expect(
          ActiveRecord::Base.connection.select_value(
            "SELECT to_regclass('pg_temp.verified_ids')::text",
          ),
        ).to be_nil
      end
    end
  end

  it "keeps the bucket folder prefix when deleting without adding it twice" do
    scoped_provider = described_class.new(S3Helper.new("uploads/site", "", client:, bucket:))
    request = stub_request(:delete, "#{endpoint}/uploads/site/backup.tar.gz").to_return(status: 204)
    scoped_provider.delete("backup.tar.gz")
    scoped_provider.delete("site/backup.tar.gz")
    expect(request).to have_been_requested.twice
  end

  %w[file.png site/file.png temp/site/file.png site-other/file.png].each do |key|
    it "preserves exact upload deletion for #{key.inspect} with a bucket folder" do
      scoped_helper = S3Helper.new("uploads/site", "", client:, bucket:)
      store = FileStore::S3Store.new(scoped_helper)
      request = stub_request(:delete, "#{endpoint}/uploads/#{key}").to_return(status: 204)

      scoped_helper.delete_object(key)
      store.delete_file(key)

      expect(request).to have_been_requested.twice
    end
  end

  it "still resolves backup filenames relative to the bucket folder when deleting" do
    scoped_provider = described_class.new(S3Helper.new("uploads/site", "", client:, bucket:))
    store = BackupRestore::S3BackupStore.new(object_storage: scoped_provider)
    stub_request(:head, "#{endpoint}/uploads/site/backup.tar.gz").to_return(
      status: 200,
      headers: {
        "Content-Length" => "5",
        "Last-Modified" => Time.now.httpdate,
      },
    )
    request = stub_request(:delete, "#{endpoint}/uploads/site/backup.tar.gz").to_return(status: 204)

    store.delete_file("backup.tar.gz")

    expect(request).to have_been_requested.once
  end

  it "deletes the exact source key after promoting a backup into its configured folder" do
    SiteSetting.s3_backup_bucket = "uploads/site"
    store = BackupRestore::S3BackupStore.new(s3_options: { client:, bucket: })
    database = RailsMultisite::ConnectionManagement.current_db
    stub_request(:head, "#{endpoint}/uploads/temp/backup.tar.gz").to_return(
      status: 200,
      headers: {
        "Content-Length" => "5",
      },
    )
    copied = false
    copy =
      stub_request(:put, "#{endpoint}/uploads/site/#{database}/backup.tar.gz")
        .with(headers: { "X-Amz-Copy-Source" => "uploads/temp/backup.tar.gz" })
        .to_return do
          copied = true
          { status: 200, body: '<CopyObjectResult><ETag>"copied"</ETag></CopyObjectResult>' }
        end
    deletion =
      stub_request(:delete, "#{endpoint}/uploads/temp/backup.tar.gz")
        .with { copied }
        .to_return(status: 204)

    store.move_existing_stored_upload(
      existing_external_upload_key: "temp/backup.tar.gz",
      original_filename: "backup.tar.gz",
    )

    expect(copy).to have_been_requested.once
    expect(deletion).to have_been_requested.once
  end

  it "normalizes failures from exact-key deletion without changing the target" do
    scoped_provider = described_class.new(S3Helper.new("uploads/site", "", client:, bucket:))
    request =
      stub_request(:delete, "#{endpoint}/uploads/file.png").to_return(
        status: 403,
        body: "<Error><Code>AccessDenied</Code></Error>",
      )
    expect { scoped_provider.delete("file.png", exact: true) }.to raise_error(
      FileStore::ObjectStorage::AccessDenied,
    ) do |error|
      expect(error.cause).to be_a(Aws::S3::Errors::AccessDenied)
    end
    expect(request).to have_been_requested.once
  end

  it "keeps exact-key deletion of missing objects idempotent" do
    scoped_provider = described_class.new(S3Helper.new("uploads/site", "", client:, bucket:))
    request =
      stub_request(:delete, "#{endpoint}/uploads/missing").to_return(
        status: 404,
        body: "<Error><Code>NoSuchKey</Code></Error>",
      )
    expect(scoped_provider.delete("missing", exact: true)).to be_nil
    expect(request).to have_been_requested.once
  end

  it "lazily traverses listing pages as plain object metadata" do
    first =
      stub_request(:get, "#{endpoint}/uploads").with(
        query: {
          "list-type" => "2",
          "prefix" => "original/",
        },
      ).to_return(
        status: 200,
        body:
          '<ListBucketResult><IsTruncated>true</IsTruncated><NextContinuationToken>next</NextContinuationToken><Contents><Key>original/a</Key><Size>1</Size><ETag>"a"</ETag></Contents></ListBucketResult>',
      )
    second =
      stub_request(:get, "#{endpoint}/uploads").with(
        query: {
          "list-type" => "2",
          "prefix" => "original/",
          "continuation-token" => "next",
        },
      ).to_return(
        status: 200,
        body:
          '<ListBucketResult><IsTruncated>false</IsTruncated><Contents><Key>original/b</Key><Size>2</Size><ETag>"b"</ETag></Contents></ListBucketResult>',
      )
    objects = provider.list("original/")
    expect(first).not_to have_been_requested
    results = objects.to_a
    expect(results.map(&:key)).to eq(%w[original/a original/b])
    expect(results.map(&:metadata)).to eq([nil, nil])
    expect(first).to have_been_requested.once
    expect(second).to have_been_requested.once
  end

  it "preserves bucket-default permissions for backup file transfers and signing" do
    SiteSetting.s3_enable_access_control_tags = true
    request =
      stub_request(:put, "#{endpoint}/uploads/backup.tar.gz")
        .with { |req| !req.headers.key?("X-Amz-Acl") && !req.headers.key?("X-Amz-Tagging") }
        .to_return(status: 200, headers: { "ETag" => '"backup"' })
    Tempfile.create do |file|
      file.write("backup bytes")
      file.flush
      provider.upload_file(
        "backup.tar.gz",
        file.path,
        visibility: :bucket_default,
        headers: {
          content_type: "application/gzip",
        },
      )
    end
    expect(request).to have_been_requested.once
    query =
      URI.decode_www_form(URI(provider.upload_url("backup.tar.gz", expires_in: 60)).query).to_h
    expect(query["X-Amz-Expires"]).to eq("60")
    expect(query.keys).not_to include("x-amz-acl", "x-amz-tagging")
  end

  %i[upload backup].each do |store_type|
    describe "legacy #{store_type} multipart responses" do
      let(:store) do
        if store_type == :upload
          FileStore::S3Store.new(helper)
        else
          SiteSetting.s3_backup_bucket = "uploads"
          BackupRestore::S3BackupStore.new(s3_options: { client:, bucket: })
        end
      end

      it "retains SDK listing fields and response context" do
        request =
          stub_request(
            :get,
            "#{endpoint}/uploads/temp/file?uploadId=session&max-parts=1&part-number-marker=1",
          ).to_return(
            status: 200,
            body:
              '<ListPartsResult><Bucket>uploads</Bucket><Key>temp/file</Key><UploadId>session</UploadId><IsTruncated>true</IsTruncated><NextPartNumberMarker>2</NextPartNumberMarker><Part><PartNumber>2</PartNumber><ETag>"part"</ETag><Size>10</Size><LastModified>2026-01-01T00:00:00Z</LastModified></Part></ListPartsResult>',
          )

        response =
          store.list_multipart_parts(
            upload_id: "session",
            key: "temp/file",
            max_parts: 1,
            start_from_part_number: 1,
          )

        expect(response.context.operation_name).to eq(:list_parts)
        expect(response.bucket).to eq("uploads")
        expect(response.key).to eq("temp/file")
        expect(response.upload_id).to eq("session")
        expect(response.is_truncated).to eq(true)
        expect(response.next_part_number_marker).to eq(2)
        expect(response.parts.first.etag).to eq('"part"')
        expect(response.parts.first.last_modified).to eq(Time.utc(2026, 1, 1))
        expect(request).to have_been_requested.once
      end

      it "retains SDK completion fields and response context" do
        request =
          stub_request(:post, "#{endpoint}/uploads/temp/file?uploadId=session")
            .with { |req| req.body.include?("<PartNumber>1</PartNumber>") }
            .to_return(
              status: 200,
              headers: {
                "x-amz-version-id" => "version-1",
              },
              body:
                '<CompleteMultipartUploadResult><Location>https://storage.example.test/uploads/temp/file</Location><Bucket>uploads</Bucket><Key>temp/file</Key><ETag>"opaque-1"</ETag></CompleteMultipartUploadResult>',
            )

        response =
          store.complete_multipart(
            upload_id: "session",
            key: "temp/file",
            parts: [{ part_number: 1, etag: '"part"' }],
          )

        expect(response.context.operation_name).to eq(:complete_multipart_upload)
        expect(response.location).to eq("#{endpoint}/uploads/temp/file")
        expect(response.bucket).to eq("uploads")
        expect(response.key).to eq("temp/file")
        expect(response.etag).to eq('"opaque-1"')
        expect(response.version_id).to eq("version-1")
        expect(request).to have_been_requested.once
      end

      it "retains the SDK abort response and context" do
        request =
          stub_request(:delete, "#{endpoint}/uploads/temp/file?uploadId=session").to_return(
            status: 204,
            headers: {
              "x-amz-request-charged" => "requester",
            },
          )

        response = store.abort_multipart(upload_id: "session", key: "temp/file")

        expect(response.context.operation_name).to eq(:abort_multipart_upload)
        expect(response.request_charged).to eq("requester")
        expect(
          store.object_storage.abort_multipart(upload_id: "session", key: "temp/file"),
        ).to be_nil
        expect(request).to have_been_requested.twice
      end

      it "preserves missing-session SDK errors for abort only at the legacy boundary" do
        stub_request(:delete, "#{endpoint}/uploads/temp/file?uploadId=missing").to_return(
          status: 404,
          body: "<Error><Code>NoSuchUpload</Code></Error>",
        )
        expect { store.abort_multipart(upload_id: "missing", key: "temp/file") }.to raise_error(
          Aws::S3::Errors::NoSuchUpload,
        )
        expect {
          store.object_storage.abort_multipart(upload_id: "missing", key: "temp/file")
        }.to raise_error(FileStore::ObjectStorage::UploadNotFound)
      end

      it "preserves the helper's part signing URL through both APIs" do
        freeze_time
        arguments = { upload_id: "session", key: "temp/file", part_number: 3 }
        expected = store.s3_helper.presign_multipart_part(**arguments)

        expect(store.presign_multipart_part(**arguments)).to eq(expected)
        expect(store.object_storage.presign_multipart_part(**arguments)).to eq(expected)
        query = URI.decode_www_form(URI(expected).query).to_h
        expect(query["partNumber"]).to eq("3")
        expect(query["uploadId"]).to eq("session")
      end

      context "without signing credentials" do
        let(:client) do
          Aws::S3::Client.new(
            endpoint: endpoint,
            region: "us-east-1",
            credentials: Aws::Credentials.new(nil, nil),
            force_path_style: true,
            retry_limit: 0,
          )
        end

        it "preserves SDK signing errors only at the legacy boundary" do
          arguments = { upload_id: "session", key: "temp/file", part_number: 1 }
          expect { store.presign_multipart_part(**arguments) }.to raise_error do |error|
            expect(error).to be_a(Aws::Errors::MissingCredentialsError).or be_a(
                   Aws::Sigv4::Errors::MissingCredentialsError,
                 )
          end
          expect { store.object_storage.presign_multipart_part(**arguments) }.to raise_error(
            FileStore::ObjectStorage::CredentialsUnavailable,
          )
        end
      end

      it "preserves missing-session SDK errors only at the legacy boundary" do
        stub_request(
          :get,
          "#{endpoint}/uploads/temp/file?uploadId=missing&max-parts=1000",
        ).to_return(status: 404, body: "<Error><Code>NoSuchUpload</Code></Error>")
        expect {
          store.list_multipart_parts(upload_id: "missing", key: "temp/file")
        }.to raise_error(Aws::S3::Errors::NoSuchUpload)
        expect {
          store.object_storage.list_multipart_parts(upload_id: "missing", key: "temp/file")
        }.to raise_error(FileStore::ObjectStorage::UploadNotFound)
      end

      it "preserves SDK completion errors only at the legacy boundary" do
        stub_request(:post, "#{endpoint}/uploads/temp/file?uploadId=session").to_return(
          status: 403,
          body: "<Error><Code>AccessDenied</Code></Error>",
        )
        arguments = {
          upload_id: "session",
          key: "temp/file",
          parts: [{ part_number: 1, etag: '"part"' }],
        }
        expect { store.complete_multipart(**arguments) }.to raise_error(
          Aws::S3::Errors::AccessDenied,
        )
        expect { store.object_storage.complete_multipart(**arguments) }.to raise_error(
          FileStore::ObjectStorage::AccessDenied,
        )
      end
    end
  end

  it "runs the multipart lifecycle without returning SDK response objects" do
    create =
      stub_request(:post, "#{endpoint}/uploads/temp/file?uploads").with(
        headers: {
          "x-amz-acl" => "private",
          "Content-Type" => "image/png",
        },
      ).to_return(
        status: 200,
        body:
          "<InitiateMultipartUploadResult><UploadId>session</UploadId></InitiateMultipartUploadResult>",
      )
    expect(provider.create_multipart("temp/file", "image/png", visibility: :private)).to eq(
      upload_id: "session",
      key: "temp/file",
    )
    list =
      stub_request(
        :get,
        "#{endpoint}/uploads/temp/file?uploadId=session&max-parts=1&part-number-marker=1",
      ).to_return(
        status: 200,
        body:
          '<ListPartsResult><IsTruncated>true</IsTruncated><NextPartNumberMarker>2</NextPartNumberMarker><Part><PartNumber>2</PartNumber><ETag>"part-etag"</ETag><Size>10</Size></Part></ListPartsResult>',
      )
    expect(
      provider.list_multipart_parts(
        upload_id: "session",
        key: "temp/file",
        max_parts: 1,
        start_from_part_number: 1,
      ),
    ).to eq(
      parts: [{ part_number: 2, etag: '"part-etag"', size: 10 }],
      truncated: true,
      next_marker: 2,
    )
    complete =
      stub_request(:post, "#{endpoint}/uploads/temp/file?uploadId=session")
        .with { |req| req.body.include?("<PartNumber>2</PartNumber>") }
        .to_return(
          status: 200,
          body:
            '<CompleteMultipartUploadResult><Key>temp/file</Key><ETag>"complete-etag"</ETag></CompleteMultipartUploadResult>',
        )
    result =
      provider.complete_multipart(
        upload_id: "session",
        key: "temp/file",
        parts: [{ part_number: 2, etag: '"part-etag"' }],
      )
    expect(result).to eq(
      FileStore::ObjectStorage::Result.new(key: "temp/file", etag: '"complete-etag"'),
    )
    abort_request =
      stub_request(:delete, "#{endpoint}/uploads/temp/abandoned?uploadId=abandoned").to_return(
        status: 204,
      )
    expect(provider.abort_multipart(upload_id: "abandoned", key: "temp/abandoned")).to be_nil
    [create, list, complete, abort_request].each do |request|
      expect(request).to have_been_requested.once
    end
  end

  it "signs downloads, direct uploads, and multipart parts without contacting storage" do
    url = provider.download_url("image.png", expires_in: 60, content_disposition: "attachment")
    query = URI.decode_www_form(URI(url).query).to_h
    expect(query["X-Amz-Expires"]).to eq("60")
    expect(query["response-content-disposition"]).to eq("attachment")
    expect(query["X-Amz-Signature"]).to be_present

    request =
      provider.upload_request(
        "temp/file",
        visibility: :private,
        expires_in: 120,
        metadata: {
          "sha1" => "digest",
        },
      )
    expect(request.key).to eq("temp/file")
    query = URI.decode_www_form(URI(request.url).query).to_h
    expect(query["X-Amz-Expires"]).to eq("120")
    expect(request.headers["x-amz-acl"]).to eq("private")
    expect(request.headers["x-amz-meta-sha1"]).to eq("digest")

    url = provider.presign_multipart_part(upload_id: "session", key: "temp/file", part_number: 3)
    query = URI.decode_www_form(URI(url).query).to_h
    expect(query.values_at("uploadId", "partNumber")).to eq(%w[session 3])
    expect(query["X-Amz-Signature"]).to be_present
  end

  it "preserves the legacy temporary-upload signing tuple" do
    store = FileStore::S3Store.new(helper, object_storage: provider)
    result = store.signed_request_for_temporary_upload("image.png", expires_in: 60)
    expect(result).to be_an(Array)
    expect(result.size).to eq(2)
    url, headers = result
    expect(URI.decode_www_form(URI(url).query).to_h["X-Amz-Expires"]).to eq("60")
    expect(headers["x-amz-acl"]).to eq("private")
  end

  it "classifies missing multipart sessions without exposing an SDK exception to callers" do
    stub_request(:get, "#{endpoint}/uploads/temp/file?uploadId=missing&max-parts=1000").to_return(
      status: 404,
      body: "<Error><Code>NoSuchUpload</Code></Error>",
    )
    expect { provider.list_multipart_parts(upload_id: "missing", key: "temp/file") }.to raise_error(
      FileStore::ObjectStorage::UploadNotFound,
    ) { |error| expect(error.cause).to be_a(Aws::S3::Errors::NoSuchUpload) }
  end

  {
    "AccessDenied" => [403, FileStore::ObjectStorage::AccessDenied],
    "InternalError" => [500, FileStore::ObjectStorage::ServiceError],
    "NoSuchBucket" => [404, FileStore::ObjectStorage::ServiceError],
    "NoSuchUpload" => [404, FileStore::ObjectStorage::UploadNotFound],
  }.each do |code, (status, error_class)|
    it "normalizes #{code} across multipart operations and preserves the original cause" do
      response = {
        status:,
        body: "<Error><Code>#{code}</Code><Message>storage failure</Message></Error>",
      }
      stub_request(:post, "#{endpoint}/uploads/temp/file?uploads").to_return(response)
      stub_request(:get, "#{endpoint}/uploads/temp/file?uploadId=session&max-parts=1000").to_return(
        response,
      )
      stub_request(:post, "#{endpoint}/uploads/temp/file?uploadId=session").to_return(response)
      stub_request(:delete, "#{endpoint}/uploads/temp/file?uploadId=session").to_return(response)

      operations = [
        -> { provider.create_multipart("temp/file", "image/png", visibility: :private) },
        -> { provider.list_multipart_parts(upload_id: "session", key: "temp/file") },
        -> do
          provider.complete_multipart(
            upload_id: "session",
            key: "temp/file",
            parts: [{ part_number: 1, etag: "part" }],
          )
        end,
        -> { provider.abort_multipart(upload_id: "session", key: "temp/file") },
      ]
      operations.each do |operation|
        expect(&operation).to raise_error(error_class, "storage failure") do |error|
          expect(error.class).to eq(error_class)
          expect(error.cause).to be_a(Aws::S3::Errors::ServiceError)
          expect(error.cause.code).to eq(code)
        end
      end
    end
  end

  it "does not disguise invalid multipart arguments as storage service failures" do
    expect {
      provider.create_multipart("temp/file", "image/png", visibility: :unknown)
    }.to raise_error(ArgumentError)
    expect {
      provider.presign_multipart_part(
        upload_id: "session",
        key: "temp/file",
        part_number: "invalid",
      )
    }.to raise_error(ArgumentError)
  end

  it "uploads bytes with provider-neutral visibility and headers" do
    request =
      stub_request(:put, "#{endpoint}/uploads/image.png").with(
        body: "image bytes",
        headers: {
          "x-amz-acl" => "private",
          "Content-Type" => "image/png",
        },
      ).to_return(status: 200, headers: { "ETag" => '"opaque-etag"' })

    Tempfile.create do |file|
      file.write("image bytes")
      file.rewind
      result =
        provider.upload(
          file,
          "image.png",
          visibility: :private,
          headers: {
            content_type: "image/png",
          },
        )
      expect(result).to eq(
        FileStore::ObjectStorage::Result.new(key: "image.png", etag: "opaque-etag"),
      )
    end
    expect(request).to have_been_requested.once
  end

  it "normalizes failed uploads for both upload entry points" do
    stub_request(:put, "#{endpoint}/uploads/denied").to_return(
      status: 403,
      body: "<Error><Code>AccessDenied</Code><Message>upload denied</Message></Error>",
    )
    Tempfile.create do |file|
      file.write("bytes")
      file.flush
      expect { provider.upload(file, "denied", visibility: :private) }.to raise_error(
        FileStore::ObjectStorage::AccessDenied,
      )
      expect {
        provider.upload_file("denied", file.path, visibility: :bucket_default)
      }.to raise_error(FileStore::ObjectStorage::AccessDenied)
    end
  end

  it "distinguishes a missing copy source from a denied copy" do
    stub_request(:head, "#{endpoint}/uploads/missing").to_return(status: 404)
    expect { provider.copy("missing", "destination", visibility: :private) }.to raise_error(
      FileStore::ObjectStorage::ObjectNotFound,
    ) do |error|
      expect(error.cause).to be_a(Aws::S3::Errors::NotFound)
    end
    stub_request(:head, "#{endpoint}/uploads/source").to_return(
      status: 200,
      headers: {
        "Content-Length" => "1",
      },
    )
    stub_request(:put, "#{endpoint}/uploads/destination").to_return(
      status: 403,
      body: "<Error><Code>AccessDenied</Code></Error>",
    )
    expect { provider.copy("source", "destination", visibility: :private) }.to raise_error(
      FileStore::ObjectStorage::AccessDenied,
    )
  end

  it "keeps deletion idempotent for missing objects" do
    stub_request(:delete, "#{endpoint}/uploads/missing").to_return(
      status: 404,
      body: "<Error><Code>NoSuchKey</Code></Error>",
    )
    expect(provider.delete("missing")).to be_nil
  end

  it "downloads bytes using the bucket folder prefix" do
    scoped_provider = described_class.new(S3Helper.new("uploads/site", "", client:, bucket:))
    stub_request(:head, "#{endpoint}/uploads/site/backup?partNumber=1").to_return(
      status: 200,
      headers: {
        "Content-Length" => "5",
      },
    )
    stub_request(:get, "#{endpoint}/uploads/site/backup").to_return(
      status: 200,
      body: "bytes",
      headers: {
        "Content-Length" => "5",
      },
    )
    Dir.mktmpdir do |directory|
      destination = File.join(directory, "backup")
      expect(scoped_provider.download("backup", destination)).to be_nil
      expect(File.read(destination)).to eq("bytes")
    end
  end

  it "preserves custom download messages and the provider error cause" do
    stub_request(:head, "#{endpoint}/uploads/denied?partNumber=1").to_return(
      status: 200,
      headers: {
        "Content-Length" => "1",
      },
    )
    stub_request(:get, "#{endpoint}/uploads/denied").to_return(
      status: 403,
      body: "<Error><Code>AccessDenied</Code></Error>",
    )
    Dir.mktmpdir do |directory|
      expect {
        provider.download(
          "denied",
          File.join(directory, "backup"),
          failure_message: "Backup download failed",
        )
      }.to raise_error(FileStore::ObjectStorage::AccessDenied, "Backup download failed") do |error|
        expect(error.cause).to be_a(Aws::S3::Errors::ServiceError)
      end
    end
  end

  it "reports missing downloads through the provider-neutral error" do
    stub_request(:head, "#{endpoint}/uploads/missing?partNumber=1").to_return(status: 404)
    stub_request(:get, "#{endpoint}/uploads/missing").to_return(
      status: 404,
      body: "<Error><Code>NoSuchKey</Code></Error>",
    )
    Dir.mktmpdir do |directory|
      expect { provider.download("missing", File.join(directory, "backup")) }.to raise_error(
        FileStore::ObjectStorage::ObjectNotFound,
        /Failed to download missing/,
      )
    end
  end

  %i[upload backup].each do |store_type|
    describe "legacy #{store_type} store download compatibility" do
      let(:store) do
        if store_type == :upload
          FileStore::S3Store.new(helper, object_storage: provider)
        else
          BackupRestore::S3BackupStore.new(object_storage: provider)
        end
      end
      let(:upload) { Fabricate.build(:upload, id: 123) }
      let(:key) { store_type == :upload ? store.get_path_for_upload(upload) : "backup.tar.gz" }

      def download_from_store(destination, message = nil)
        if store.is_a?(FileStore::S3Store)
          store.download_file(upload, destination)
        else
          store.download_file(key, destination, message)
        end
      end

      %i[denied local].each do |failure|
        it "preserves the legacy error class and message for #{failure} failures" do
          stub_request(:head, "#{endpoint}/uploads/#{key}?partNumber=1").to_return(
            status: 200,
            headers: {
              "Content-Length" => "5",
            },
          )
          stub_request(:get, "#{endpoint}/uploads/#{key}").to_return(
            (
              if failure == :denied
                { status: 403, body: "<Error><Code>AccessDenied</Code></Error>" }
              else
                { status: 200, body: "bytes", headers: { "Content-Length" => "5" } }
              end
            ),
          )

          Dir.mktmpdir do |directory|
            destination =
              (
                if failure == :local
                  File.join(directory, "missing", "download")
                else
                  File.join(directory, "download")
                end
              )
            legacy_error = nil
            expect { helper.download_file(key, destination) }.to raise_error(
              RuntimeError,
            ) do |error|
              legacy_error = error
            end
            expect { download_from_store(destination) }.to raise_error(RuntimeError) do |error|
              expect(error.class).to eq(legacy_error.class)
              # The SDK uses a fresh random suffix for each temporary download file.
              expect(error.message.sub(/\.s3tmp\.\w+\z/, ".s3tmp")).to eq(
                legacy_error.message.sub(/\.s3tmp\.\w+\z/, ".s3tmp"),
              )
              expect(error.cause).to be_present
              if failure == :local
                expect(error.cause).to be_a(Errno::ENOENT)
              else
                expect(error.cause).to be_a(FileStore::ObjectStorage::AccessDenied)
              end
            end
          end
        end
      end

      it "still downloads the original bytes" do
        stub_request(:head, "#{endpoint}/uploads/#{key}?partNumber=1").to_return(
          status: 200,
          headers: {
            "Content-Length" => "5",
          },
        )
        stub_request(:get, "#{endpoint}/uploads/#{key}").to_return(
          status: 200,
          body: "bytes",
          headers: {
            "Content-Length" => "5",
          },
        )
        Dir.mktmpdir do |directory|
          destination = File.join(directory, "download")
          download_from_store(destination)
          expect(File.read(destination)).to eq("bytes")
        end
      end
    end
  end

  it "preserves a backup's custom failure message for local filesystem errors" do
    stub_request(:head, "#{endpoint}/uploads/backup?partNumber=1").to_return(
      status: 200,
      headers: {
        "Content-Length" => "5",
      },
    )
    stub_request(:get, "#{endpoint}/uploads/backup").to_return(
      status: 200,
      body: "bytes",
      headers: {
        "Content-Length" => "5",
      },
    )
    store = BackupRestore::S3BackupStore.new(object_storage: provider)
    Dir.mktmpdir do |directory|
      expect {
        store.download_file("backup", File.join(directory, "missing", "backup"), "Restore failed")
      }.to raise_error(RuntimeError, "Restore failed")
    end
  end

  it "does not disguise local upload filesystem failures as provider errors" do
    Dir.mktmpdir do |directory|
      expect {
        provider.upload_file("backup", File.join(directory, "missing"), visibility: :bucket_default)
      }.to raise_error(Errno::ENOENT)
    end
  end

  it "normalizes failed large-file transfers while retaining per-part failures" do
    stub_request(:post, "#{endpoint}/uploads/large?uploads").to_return(
      status: 200,
      body:
        "<InitiateMultipartUploadResult><UploadId>session</UploadId></InitiateMultipartUploadResult>",
    )
    stub_request(:put, "#{endpoint}/uploads/large").with(
      query: hash_including("uploadId" => "session", "partNumber" => /\d+/),
    ).to_return(status: 403, body: "<Error><Code>AccessDenied</Code></Error>")
    abort_request =
      stub_request(:delete, "#{endpoint}/uploads/large?uploadId=session").to_return(status: 204)
    Tempfile.create do |file|
      file.truncate(16.megabytes)
      expect { provider.upload(file, "large", visibility: :private) }.to raise_error(
        FileStore::ObjectStorage::Error,
      ) do |error|
        expect(error.cause).to be_a(Aws::S3::MultipartUploadError)
        expect(error.cause.errors).to all(be_a(Aws::S3::Errors::AccessDenied))
      end
    end
    expect(abort_request).to have_been_requested.once
  end

  [false, true].each do |multisite|
    [nil, "site"].each do |folder|
      it "moves removed uploads to tombstones with multisite=#{multisite} and folder=#{folder.inspect}" do
        Rails.configuration.stubs(:multisite).returns(multisite)
        SiteSetting.s3_enable_access_control_tags = true
        SiteSetting.s3_upload_bucket = ["uploads", folder].compact.join("/")
        tombstone_prefix =
          multisite ? FileStore::S3Store.new.multisite_tombstone_prefix : "tombstone/"
        store =
          FileStore::S3Store.new(
            S3Helper.new(SiteSetting.s3_upload_bucket, tombstone_prefix, client:, bucket:),
          )
        path = "original/1X/file.png"
        source = [folder, multisite ? store.upload_path : nil, path].compact.join("/")
        tombstone = [
          folder,
          multisite ? store.multisite_tombstone_prefix.delete_suffix("/") : "tombstone",
          path,
        ].compact.join("/")
        stub_request(:head, "#{endpoint}/uploads/#{source}").to_return(
          status: 200,
          headers: {
            "Content-Length" => "1",
          },
        )
        copied = false
        copy =
          stub_request(:put, "#{endpoint}/uploads/#{tombstone}")
            .with do |request|
              !request.headers.key?("X-Amz-Acl") && !request.headers.key?("X-Amz-Tagging")
            end
            .to_return do
              copied = true
              { status: 200, body: '<CopyObjectResult><ETag>"copied"</ETag></CopyObjectResult>' }
            end
        deletion =
          stub_request(:delete, "#{endpoint}/uploads/#{source}")
            .with { copied }
            .to_return(status: 204)
        store.remove_file("#{store.absolute_base_url}/#{source}", path)
        expect(copy).to have_been_requested.once
        expect(deletion).to have_been_requested.once
      end
    end
  end

  it "does not delete the source when the tombstone copy fails" do
    SiteSetting.s3_upload_bucket = "uploads"
    store = FileStore::S3Store.new(S3Helper.new("uploads", "tombstone/", client:, bucket:))
    stub_request(:head, "#{endpoint}/uploads/original/file").to_return(
      status: 200,
      headers: {
        "Content-Length" => "1",
      },
    )
    stub_request(:put, "#{endpoint}/uploads/tombstone/original/file").to_return(
      status: 403,
      body: "<Error><Code>AccessDenied</Code></Error>",
    )
    deletion = stub_request(:delete, "#{endpoint}/uploads/original/file")
    expect {
      store.remove_file("#{store.absolute_base_url}/original/file", "original/file")
    }.to raise_error(Aws::S3::Errors::AccessDenied)
    expect(deletion).not_to have_been_requested
  end

  [false, true].each do |multisite|
    [nil, "site"].each do |folder|
      ["archive/", ""].each do |tombstone|
        it "matches legacy removal with multisite=#{multisite}, folder=#{folder.inspect}, tombstone=#{tombstone.inspect}" do
          Rails.configuration.stubs(:multisite).returns(multisite)
          SiteSetting.s3_upload_bucket = "uploads/configured"
          legacy_helper =
            S3Helper.new(["uploads", folder].compact.join("/"), tombstone, client:, bucket:)
          store = FileStore::S3Store.new(legacy_helper)
          requests = []
          stub_request(:any, %r{\A#{Regexp.escape(endpoint)}/uploads/}).to_return do |request|
            requests << [
              request.method,
              request.uri.path,
              request.headers.slice(
                "X-Amz-Copy-Source",
                "X-Amz-Acl",
                "X-Amz-Tagging",
                "X-Amz-Metadata-Directive",
              ),
            ]
            case request.method
            when :head
              { status: 200, headers: { "Content-Length" => "1" } }
            when :put
              { status: 200, body: '<CopyObjectResult><ETag>"copied"</ETag></CopyObjectResult>' }
            when :delete
              { status: 204 }
            else
              raise "Unexpected storage operation: #{request.method}"
            end
          end

          [
            "original/file.png",
            "site/original/file.png",
            "#{store.upload_path}/original/file.png",
          ].each do |path|
            aggregate_failures(path) do
              path.freeze
              requests.clear
              legacy_helper.remove(path, true)
              legacy_requests = requests.dup
              requests.clear

              url = "#{store.absolute_base_url}/configured/#{path}"
              expect(store.has_been_uploaded?(url)).to eq(true)
              store.remove_file(url, path)

              expect(requests).to eq(legacy_requests)
              expect(requests.last&.first).to eq(:delete)
            end
          end
        end
      end
    end
  end

  it "does not invent a tombstone when the injected helper has none configured" do
    store = FileStore::S3Store.new(helper, object_storage: provider)
    request = stub_request(:delete, "#{endpoint}/uploads/original/file").to_return(status: 204)

    store.remove_file("#{store.absolute_base_url}/original/file", "original/file")

    expect(request).to have_been_requested.once
  end

  it "keeps removal of missing uploads idempotent" do
    SiteSetting.s3_upload_bucket = "uploads"
    store = FileStore::S3Store.new(S3Helper.new("uploads", "tombstone/", client:, bucket:))
    stub_request(:head, "#{endpoint}/uploads/original/missing").to_return(status: 404)
    expect(
      store.remove_file("#{store.absolute_base_url}/original/missing", "original/missing"),
    ).to be_nil
  end

  it "copies cached avatars through the adapter with bucket-default options" do
    SiteSetting.s3_upload_bucket = "uploads"
    SiteSetting.s3_enable_access_control_tags = true
    store = FileStore::S3Store.new(helper, object_storage: provider)
    avatar =
      OptimizedImage.new(upload_id: 42, width: 120, url: "#{store.absolute_base_url}/avatar.png")
    destination = store.avatar_template(avatar, 123).sub(store.absolute_base_url + "/", "")
    stub_request(:head, "#{endpoint}/uploads/avatar.png").to_return(
      status: 200,
      headers: {
        "Content-Length" => "1",
      },
    )
    request =
      stub_request(:put, "#{endpoint}/uploads/#{destination}")
        .with do |req|
          !req.headers.key?("X-Amz-Acl") && !req.headers.key?("X-Amz-Tagging") &&
            !req.headers.key?("X-Amz-Metadata-Directive")
        end
        .to_return(status: 200, body: '<CopyObjectResult><ETag>"avatar"</ETag></CopyObjectResult>')
    expect(store.cache_avatar(avatar, 123)).to eq([destination, "avatar"])
    expect(request).to have_been_requested.once
  end

  it "does not remove files belonging to an unrelated storage URL" do
    store = FileStore::S3Store.new(helper, object_storage: provider)
    expect(store.remove_file("https://unrelated.example.test/file", "original/file")).to be_nil
  end

  it "copies metadata and preserves caller headers" do
    stub_request(:head, "#{endpoint}/uploads/source.png").to_return(
      status: 200,
      headers: {
        "Content-Length" => "10",
      },
    )
    request =
      stub_request(:put, "#{endpoint}/uploads/destination.png").with(
        headers: {
          "x-amz-copy-source" => "uploads/source.png",
          "x-amz-metadata-directive" => "REPLACE",
          "x-amz-acl" => "public-read",
        },
      ).to_return(status: 200, body: '<CopyObjectResult><ETag>"copied"</ETag></CopyObjectResult>')
    headers = { content_type: "image/png" }.freeze
    result =
      provider.copy(
        "source.png",
        "destination.png",
        visibility: :public,
        headers:,
        replace_metadata: true,
      )
    expect(result.key).to eq("destination.png")
    expect(result.etag).to eq("copied")
    expect(request).to have_been_requested.once
  end

  it "preserves ACL-disabled configurations" do
    SiteSetting.s3_use_acls = false
    request =
      stub_request(:put, "#{endpoint}/uploads/image.png")
        .with { |req| !req.headers.key?("X-Amz-Acl") }
        .to_return(status: 200, headers: { "ETag" => '"etag"' })
    Tempfile.create { |file| provider.upload(file, "image.png", visibility: :private) }
    expect(request).to have_been_requested.once
  end

  it "does not hide deletion failures" do
    stub_request(:delete, "#{endpoint}/uploads/image.png").to_return(
      status: 403,
      body: "<Error><Code>AccessDenied</Code></Error>",
    )
    expect { provider.delete("image.png") }.to raise_error(
      FileStore::ObjectStorage::AccessDenied,
    ) do |error|
      expect(error.cause).to be_a(Aws::S3::Errors::AccessDenied)
    end
  end

  it "rejects invalid visibility and provider-specific options before sending a request" do
    expect { provider.copy("a", "b", visibility: :unknown) }.to raise_error(ArgumentError)
    expect {
      provider.copy("a", "b", visibility: :private, headers: { acl: "public-read" })
    }.to raise_error(ArgumentError)
  end
end
