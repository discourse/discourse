# frozen_string_literal: true

class FakeS3
  attr_reader :s3_client

  def self.create
    s3 = self.new
    s3.stub_bucket(SiteSetting.s3_upload_bucket) if SiteSetting.s3_upload_bucket.present?
    if SiteSetting.s3_backup_bucket.present?
      s3.stub_bucket(
        File.join(SiteSetting.s3_backup_bucket, RailsMultisite::ConnectionManagement.current_db),
      )
    end
    s3.stub_s3_helper
    s3
  end

  def initialize
    @buckets = {}
    @operations = []
    @s3_client = Aws::S3::Client.new(stub_responses: true, region: SiteSetting.s3_region)

    stub_methods
  end

  def bucket(bucket_name)
    bucket_name, _prefix = bucket_name.split("/", 2)
    @buckets[bucket_name]
  end

  def stub_bucket(full_bucket_name)
    bucket_name, _prefix = full_bucket_name.split("/", 2)

    s3_helper =
      S3Helper.new(
        full_bucket_name,
        (
          if Rails.configuration.multisite
            FileStore::S3Store.new.multisite_tombstone_prefix
          else
            FileStore::S3Store::TOMBSTONE_PREFIX
          end
        ),
        client: @s3_client,
      )
    @buckets[bucket_name] = FakeS3Bucket.new(full_bucket_name, s3_helper)
  end

  def stub_s3_helper
    @buckets.each do |bucket_name, bucket|
      S3Helper
        .stubs(:new)
        .with { |b| b == bucket_name || b == bucket.name }
        .returns(bucket.s3_helper)
    end
  end

  def operation_called?(name)
    @operations.any? do |operation|
      operation[:name] == name && (block_given? ? yield(operation) : true)
    end
  end

  private

  def find_bucket(params)
    bucket(params[:bucket])
  end

  def find_object(params)
    bucket = find_bucket(params)
    bucket&.find_object(params[:key])
  end

  def log_operation(context)
    @operations << { name: context.operation_name, params: context.params.dup }
  end

  def calculate_etag(context)
    # simple, reproducible ETag calculation
    Digest::MD5.hexdigest(context.params.to_json)
  end

  def stub_methods
    @s3_client.stub_responses(
      :head_object,
      ->(context) do
        log_operation(context)

        if object = find_object(context.params)
          {
            content_length: object[:size],
            last_modified: object[:last_modified],
            metadata: object[:metadata],
          }
        else
          { status_code: 404, headers: {}, body: "" }
        end
      end,
    )

    @s3_client.stub_responses(
      :get_object,
      ->(context) do
        log_operation(context)

        if object = find_object(context.params)
          { content_length: object[:size], body: "" }
        else
          { status_code: 404, headers: {}, body: "" }
        end
      end,
    )

    @s3_client.stub_responses(
      :delete_object,
      ->(context) do
        log_operation(context)

        find_bucket(context.params)&.delete_object(context.params[:key])
        nil
      end,
    )

    @s3_client.stub_responses(
      :copy_object,
      ->(context) do
        log_operation(context)

        source_bucket_name, source_key = context.params[:copy_source].split("/", 2)
        copy_source = { bucket: source_bucket_name, key: source_key }

        if context.params[:metadata_directive] == "REPLACE"
          attribute_overrides = context.params.except(:copy_source, :metadata_directive)
        else
          attribute_overrides = context.params.slice(:key, :bucket)
        end

        new_object = find_object(copy_source).dup.merge(attribute_overrides)
        find_bucket(new_object).put_object(new_object)

        { copy_object_result: { etag: calculate_etag(context) } }
      end,
    )

    @s3_client.stub_responses(
      :create_multipart_upload,
      ->(context) do
        log_operation(context)

        find_bucket(context.params).put_object(context.params)
        { upload_id: SecureRandom.hex }
      end,
    )

    @s3_client.stub_responses(
      :put_object,
      ->(context) do
        log_operation(context)

        find_bucket(context.params).put_object(context.params)
        { etag: calculate_etag(context) }
      end,
    )
  end
end

class FakeS3Bucket
  attr_reader :name, :s3_helper

  def initialize(bucket_name, s3_helper)
    @name = bucket_name
    @s3_helper = s3_helper
    @objects = {}
  end

  def put_object(obj)
    @objects[obj[:key]] = obj
  end

  def delete_object(key)
    @objects.delete(key)
  end

  def find_object(key)
    @objects[key]
  end
end
