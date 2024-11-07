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
      end,
    )

    setup_s3
    SiteSetting.s3_backup_bucket = "s3-backup-bucket"
    SiteSetting.backup_location = BackupLocationSiteSetting::S3
  end

  let(:expected_type) { BackupRestore::S3BackupStore }

  it_behaves_like "backup store"
  it_behaves_like "remote backup store"

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
end
