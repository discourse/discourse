# frozen_string_literal: true

require "s3_helper"
require "backup_restore/s3_backup_store"
require_relative "shared_examples_for_backup_store"

RSpec.describe BackupRestore::S3BackupStore do
  subject(:store) { BackupRestore::BackupStore.create(s3_options: @s3_options) }

  before do
    @s3_client = Aws::S3::Client.new(stub_responses: true)
    @s3_options = { client: @s3_client }

    @objects = []

    def expected_prefix
      "#{RailsMultisite::ConnectionManagement.current_db}/"
    end

    def check_context(context)
      expect(context.params[:bucket]).to eq(SiteSetting.s3_backup_bucket)
      expect(context.params[:key]).to start_with(expected_prefix) if context.params.key?(:key)
      expect(context.params[:prefix]).to eq(expected_prefix) if context.params.key?(:prefix)
    end

    @s3_client.stub_responses(
      :list_objects_v2,
      ->(context) do
        check_context(context)

        { contents: objects_with_prefix(context) }
      end,
    )

    @s3_client.stub_responses(
      :delete_object,
      ->(context) do
        check_context(context)

        expect do @objects.delete_if { |obj| obj[:key] == context.params[:key] } end.to change {
          @objects
        }

        { delete_marker: true }
      end,
    )

    @s3_client.stub_responses(
      :head_object,
      ->(context) do
        check_context(context)

        if object = @objects.find { |obj| obj[:key] == context.params[:key] }
          { content_length: object[:size], last_modified: object[:last_modified] }
        else
          { status_code: 404, headers: {}, body: "" }
        end
      end,
    )

    @s3_client.stub_responses(
      :get_object,
      ->(context) do
        check_context(context)

        if object = @objects.find { |obj| obj[:key] == context.params[:key] }
          { content_length: object[:size], body: "A" * object[:size] }
        else
          { status_code: 404, headers: {}, body: "" }
        end
      end,
    )

    @s3_client.stub_responses(
      :put_object,
      ->(context) do
        check_context(context)

        @objects << {
          key: context.params[:key],
          size: context.params[:body].size,
          last_modified: Time.zone.now,
        }

        { etag: "test-etag" }
      end,
    )

    setup_s3
    SiteSetting.s3_backup_bucket = "s3-backup-bucket"
    SiteSetting.backup_location = BackupLocationSiteSetting::S3
  end

  let(:expected_type) { BackupRestore::S3BackupStore }

  it_behaves_like "backup store"
  it_behaves_like "remote backup store"

  describe "#upload_stream" do
    around { |example| stub_const(BackupRestore::MultipartWriter, "PART_SIZE", 8) { example.run } }

    before do
      @s3_client.stub_responses(:create_multipart_upload, upload_id: "stream-id")
      @uploaded_parts = []
      @s3_client.stub_responses(
        :upload_part,
        ->(context) do
          @uploaded_parts[context.params[:part_number] - 1] = context.params[:body].read
          { etag: "etag-#{context.params[:part_number]}" }
        end,
      )
    end

    it "uploads bounded parts in order, including the final short part" do
      store.upload_stream("backup.tar", "application/x-tar") do |io|
        expect(io.write("123")).to eq(3)
        io.write("456789abcdefghijk")
      end

      expect(@uploaded_parts).to eq(%w[12345678 9abcdefg hijk])
      requests = @s3_client.api_requests
      create = requests.find { |r| r[:operation_name] == :create_multipart_upload }[:params]
      expect(create).to include(key: "default/backup.tar", content_type: "application/x-tar")
      complete = requests.find { |r| r[:operation_name] == :complete_multipart_upload }[:params]
      expect(complete[:multipart_upload][:parts]).to eq(
        (1..3).map { |number| { part_number: number, etag: "etag-#{number}" } },
      )
      expect(requests.none? { |r| r[:operation_name] == :abort_multipart_upload }).to eq(true)
    end

    it "streams a tar archive that can be extracted after the parts are joined" do
      Dir.mktmpdir do |directory|
        source = File.join(directory, "source")
        File.binwrite(source, "contents\0" * 20)
        store.upload_stream("backup.tar", "application/x-tar") do |io|
          BackupRestore::ArchiveWriter.write(io) do |archive|
            archive.add_file(source, "first")
            archive.add_hardlink("second", "first")
          end
        end

        filename = File.join(directory, "backup.tar")
        File.binwrite(filename, @uploaded_parts.join)
        Discourse::Utils.execute_command("tar", "-xf", filename, "-C", directory)
        expect(File.binread(File.join(directory, "first"))).to eq(File.binread(source))
        expect(File.stat(File.join(directory, "first")).ino).to eq(
          File.stat(File.join(directory, "second")).ino,
        )
      end
    end

    it "does not upload an empty trailing part at an exact boundary" do
      store.upload_stream("backup.tar", "application/x-tar") { |io| io.write("12345678") }
      expect(@uploaded_parts).to eq(["12345678"])
    end

    it "preserves the original failure if abort also fails" do
      @s3_client.stub_responses(:abort_multipart_upload, "AccessDenied")
      expect do
        store.upload_stream("backup.tar", "application/x-tar") { raise "archive failed" }
      end.to raise_error(RuntimeError, "archive failed")
    end

    [RuntimeError, SystemExit].each do |error|
      it "aborts when the archive producer raises #{error}" do
        expect do
          store.upload_stream("backup.tar", "application/x-tar") do |io|
            io.write("12345678")
            raise error
          end
        end.to raise_error(error)

        operations = @s3_client.api_requests.map { |r| r[:operation_name] }
        expect(operations).to include(:abort_multipart_upload)
        expect(operations).not_to include(:complete_multipart_upload)
      end
    end

    %i[upload_part complete_multipart_upload].each do |operation|
      it "aborts when #{operation} fails" do
        @s3_client.stub_responses(operation, "AccessDenied")
        expect do
          store.upload_stream("backup.tar", "application/x-tar") { |io| io.write("data") }
        end.to raise_error(Aws::S3::Errors::AccessDenied)
        expect(@s3_client.api_requests.last[:operation_name]).to eq(:abort_multipart_upload)
      end
    end

    it "refuses to replace an existing backup" do
      @s3_client.stub_responses(:head_object, {})
      expect do
        store.upload_stream("backup.tar", "application/x-tar") { raise "must not run" }
      end.to raise_error(BackupRestore::BackupStore::BackupFileExists)
    end

    it "aborts before exceeding the S3 part count limit" do
      stub_const(BackupRestore::MultipartWriter, "MAX_PARTS", 1) do
        expect do
          store.upload_stream("backup.tar", "application/x-tar") { |io| io.write("123456789") }
        end.to raise_error(/multipart upload limit/)
      end
      expect(@s3_client.api_requests.count { |r| r[:operation_name] == :upload_part }).to be <= 1
      expect(@s3_client.api_requests.last[:operation_name]).to eq(:abort_multipart_upload)
    end
  end

  it "lists plain tar backups but hides partial archives" do
    %w[backup.tar backup.tar.partial].each do |filename|
      @objects << {
        key: "default/#{filename}",
        size: 17,
        last_modified: Time.parse("2018-09-13T15:10:00Z"),
      }
    end

    expect(store.files.map(&:filename)).to eq(["backup.tar"])
  end

  describe "S3 specific behavior" do
    before { create_backups }
    after { remove_backups }

    describe "#delete_old" do
      it "doesn't delete files when cleanup is disabled" do
        SiteSetting.maximum_backups = 1
        SiteSetting.s3_disable_cleanup = true

        expect { store.delete_old }.to_not change { store.files }
      end
    end

    describe "#stats" do
      it "returns nil for 'free_bytes'" do
        expect(store.stats[:free_bytes]).to be_nil
      end
    end

    describe "#files" do
      # Regression: the listing was wrapped in a bare `rescue StandardError`
      # whose body was the constant `NoMethodError` - it caught everything and
      # did nothing, so an AccessDenied returned an empty list. A site whose
      # IAM policy did not cover its backup prefix showed "no backups", and the
      # restore then failed with "Failed to download archive to tmp directory."
      # instead of naming the permission that was actually missing.
      it "raises StorageError when S3 denies the listing" do
        @s3_client.stub_responses(:list_objects_v2, "AccessDenied")

        expect { store.files }.to raise_error(BackupRestore::BackupStore::StorageError)
      end

      it "still returns an empty list when the bucket genuinely has no backups" do
        remove_backups

        expect(store.files).to eq([])
      end
    end
  end

  def objects_with_prefix(context)
    prefix = context.params[:prefix]
    @objects.select { |obj| obj[:key].start_with?(prefix) }
  end

  def create_backups
    @objects.clear

    @objects << {
      key: "default/b.tar.gz",
      size: 17,
      last_modified: Time.parse("2018-09-13T15:10:00Z"),
    }
    @objects << {
      key: "default/a.tgz",
      size: 29,
      last_modified: Time.parse("2018-02-11T09:27:00Z"),
    }
    @objects << {
      key: "default/r.sql.gz",
      size: 11,
      last_modified: Time.parse("2017-12-20T03:48:00Z"),
    }
    @objects << {
      key: "default/no-backup.txt",
      size: 12,
      last_modified: Time.parse("2018-09-05T14:27:00Z"),
    }
    @objects << {
      key: "default/subfolder/c.tar.gz",
      size: 23,
      last_modified: Time.parse("2019-01-24T18:44:00Z"),
    }

    @objects << {
      key: "second/multi-2.tar.gz",
      size: 19,
      last_modified: Time.parse("2018-11-27T03:16:54Z"),
    }
    @objects << {
      key: "second/multi-1.tar.gz",
      size: 22,
      last_modified: Time.parse("2018-11-26T03:17:09Z"),
    }
    @objects << {
      key: "second/subfolder/multi-3.tar.gz",
      size: 23,
      last_modified: Time.parse("2019-01-24T18:44:00Z"),
    }
  end

  def remove_backups
    @objects.clear
  end

  def source_regex(db_name, filename, multisite:)
    bucket = Regexp.escape(SiteSetting.s3_backup_bucket)
    prefix = file_prefix(db_name, multisite)
    filename = Regexp.escape(filename)
    expires = SiteSetting.s3_presigned_get_url_expires_after_seconds

    %r{\Ahttps://#{bucket}.*#{prefix}/#{filename}\?.*X-Amz-Expires=#{expires}.*X-Amz-Signature=.*\z}
  end

  def upload_url_regex(db_name, filename, multisite:)
    bucket = Regexp.escape(SiteSetting.s3_backup_bucket)
    prefix = file_prefix(db_name, multisite)
    filename = Regexp.escape(filename)
    expires = BackupRestore::S3BackupStore::UPLOAD_URL_EXPIRES_AFTER_SECONDS

    %r{\Ahttps://#{bucket}.*#{prefix}/#{filename}\?.*X-Amz-Expires=#{expires}.*X-Amz-Signature=.*\z}
  end

  def file_prefix(db_name, multisite)
    multisite ? "\\/#{db_name}" : ""
  end

  describe "#create_multipart" do
    it "sets the ACL context when s3_use_acls is enabled" do
      SiteSetting.s3_use_acls = true
      response = store.create_multipart("test_file.tar.gz", "application/gzip", metadata: {})

      create_multipart_upload_request =
        @s3_client.api_requests.find do |api_request|
          api_request[:operation_name] == :create_multipart_upload
        end

      expect(create_multipart_upload_request[:context].params[:acl]).to eq(
        FileStore::S3Store::CANNED_ACL_PRIVATE,
      )
    end

    it "omits the ACL context when s3_use_acls is disabled" do
      SiteSetting.s3_use_acls = false
      store.create_multipart("test_file.tar.gz", "application/gzip", metadata: {})

      create_multipart_upload_request =
        @s3_client.api_requests.find do |api_request|
          api_request[:operation_name] == :create_multipart_upload
        end

      expect(create_multipart_upload_request[:context].params[:acl]).to eq(nil)
    end

    it "sets the tagging context when s3_enable_access_control_tags is enabled" do
      SiteSetting.s3_enable_access_control_tags = true
      store.create_multipart("test_file.tar.gz", "application/gzip", metadata: {})

      create_multipart_upload_request =
        @s3_client.api_requests.find do |api_request|
          api_request[:operation_name] == :create_multipart_upload
        end

      expect(
        URI.decode_www_form_component(create_multipart_upload_request[:context].params[:tagging]),
      ).to eq(
        "#{SiteSetting.s3_access_control_tag_key}=#{SiteSetting.s3_access_control_tag_private_value}",
      )
    end
  end

  describe "#move_existing_stored_upload" do
    before { create_backups }
    after { remove_backups }

    it "sets the ACL context when s3_use_acls is enabled" do
      store.move_existing_stored_upload(
        existing_external_upload_key: "default/b.tar.gz",
        original_filename: "b.tar.gz",
        content_type: "application/gzip",
      )

      copy_object_request =
        @s3_client.api_requests.find { |api_request| api_request[:operation_name] == :copy_object }

      expect(copy_object_request[:context].params[:acl]).to eq(
        FileStore::S3Store::CANNED_ACL_PRIVATE,
      )
    end

    it "omits the ACL context when s3_use_acls is disabled" do
      SiteSetting.s3_use_acls = false

      store.move_existing_stored_upload(
        existing_external_upload_key: "default/b.tar.gz",
        original_filename: "b.tar.gz",
        content_type: "application/gzip",
      )

      copy_object_request =
        @s3_client.api_requests.find { |api_request| api_request[:operation_name] == :copy_object }

      expect(copy_object_request[:context].params[:acl]).to eq(nil)
    end

    it "sets the tagging context when s3_enable_access_control_tags is enabled" do
      SiteSetting.s3_enable_access_control_tags = true

      store.move_existing_stored_upload(
        existing_external_upload_key: "default/b.tar.gz",
        original_filename: "b.tar.gz",
        content_type: "application/gzip",
      )

      copy_object_request =
        @s3_client.api_requests.find { |api_request| api_request[:operation_name] == :copy_object }

      expect(URI.decode_www_form_component(copy_object_request[:context].params[:tagging])).to eq(
        "#{SiteSetting.s3_access_control_tag_key}=#{SiteSetting.s3_access_control_tag_private_value}",
      )
    end
  end
end
