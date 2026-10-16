# frozen_string_literal: true

require "s3_helper"
require "file_store/object_storage/result"
require "file_store/object_storage/object_info"
require "file_store/object_storage/signed_request"
require "file_store/object_storage/error"
require "file_store/object_storage/service_error"
require "file_store/object_storage/upload_not_found"
require "file_store/object_storage/access_denied"
require "file_store/object_storage/object_not_found"
require "file_store/object_storage/credentials_unavailable"
require "file_store/object_storage/connection_error"

module FileStore
  module ObjectStorage
    class S3
      HEADERS = %i[cache_control content_type content_disposition content_encoding].freeze
      SDK_ERRORS = [
        Aws::Errors::ServiceError,
        Seahorse::Client::NetworkingError,
        Aws::Errors::MissingCredentialsError,
        Aws::Sigv4::Errors::MissingCredentialsError,
        Aws::S3::MultipartUploadError,
        Aws::S3::MultipartDownloadError,
      ].freeze
      private_constant :SDK_ERRORS

      def initialize(helper)
        @helper = helper
      end

      def self.sdk_error?(error)
        SDK_ERRORS.any? { |error_class| error.is_a?(error_class) }
      end

      # The SDK exception behind an adapter error, for callers that still rescue
      # SDK errors; anything else as it is.
      def self.legacy_error(error)
        error.is_a?(Error) && sdk_error?(error.cause) ? error.cause : error
      end

      def self.raise_legacy(error)
        original = legacy_error(error)
        raise original, cause: original.cause
      end

      def self.acl_for(visibility)
        return if !SiteSetting.s3_use_acls
        visibility == :private ? "private" : "public-read"
      end

      def self.tags_for(visibility, encode_form: true)
        return if !SiteSetting.s3_enable_access_control_tags
        key = SiteSetting.s3_access_control_tag_key
        return if key.blank?
        value =
          (
            if visibility == :private
              SiteSetting.s3_access_control_tag_private_value
            else
              SiteSetting.s3_access_control_tag_public_value
            end
          )
        tags = { key => value }
        encode_form ? URI.encode_www_form(tags) : tags
      end

      def self.visibility_options(visibility)
        options = {}
        if acl = acl_for(visibility)
          options[:acl] = acl
        end
        if tags = tags_for(visibility)
          options[:tagging] = tags
        end
        options
      end

      def set_visibility(key, visibility:, reset_existing_permissions: false)
        if %i[public private].exclude?(visibility)
          raise ArgumentError, "Unknown object visibility: #{visibility.inspect}"
        end
        acl = self.class.acl_for(visibility)
        if acl.present? || reset_existing_permissions
          begin
            @helper.object(key).acl.put(acl:)
          rescue Aws::S3::Errors::NotImplemented => error
            Discourse.warn_exception(
              error,
              message: "The file store object storage provider does not support setting ACLs",
            )
          end
        end
        if tags = self.class.tags_for(visibility, encode_form: false)
          @helper.upsert_tag(key, tag_key: tags.keys.first, tag_value: tags.values.first)
        end
      rescue Aws::S3::Errors::NoSuchKey
        Rails.logger.warn(
          "Could not update access control on upload with key: '#{key}'. Upload is missing.",
        )
      rescue *SDK_ERRORS => error
        raise_storage_error(error)
      end

      def upload(file, key, visibility:, headers: {})
        key, etag = @helper.upload(file, key, options(visibility, headers))
        Result.new(key:, etag:)
      rescue *SDK_ERRORS => error
        raise_storage_error(error)
      end

      def copy(source, destination, visibility:, headers: {}, replace_metadata: false)
        opts = options(visibility, headers)
        opts[:apply_metadata_to_destination] = true if replace_metadata
        key, etag = @helper.copy(source, destination, options: opts)
        Result.new(key:, etag:)
      rescue *SDK_ERRORS => error
        raise_storage_error(error)
      end

      # Migration transfers deliberately remain a single PUT, with their
      # caller-computed checksum rather than the multipart upload threshold.
      def put(file, key, visibility:, headers: {}, content_md5: nil)
        opts = options(visibility, headers).merge(body: file, content_md5:)
        object = @helper.object(key)
        begin
          response = object.put(opts)
        rescue Aws::S3::Errors::MetadataTooLarge
          raise if opts[:content_disposition].blank?
          opts.delete(:content_disposition)
          file.rewind if file.respond_to?(:rewind)
          retry
        end
        Result.new(key: object.key, etag: response.etag)
      rescue *SDK_ERRORS => error
        raise_storage_error(error)
      end

      def delete(key, exact: false)
        @helper.delete_object(exact ? key : @helper.object(key).key)
        nil
      rescue *SDK_ERRORS => error
        raise_storage_error(error)
      end

      # Preserve the helper's configured tombstone and multisite path semantics.
      def remove(path, tombstone: true)
        @helper.remove(path, tombstone)
        nil
      rescue *SDK_ERRORS => error
        raise_storage_error(error)
      end

      def download(key, destination, failure_message: nil)
        object = @helper.object(key)
        Aws::S3::TransferManager.new(client: @helper.s3_client).download_file(
          destination,
          bucket: object.bucket_name,
          key: object.key,
        )
        nil
      rescue *SDK_ERRORS => error
        message =
          failure_message&.to_s ||
            "Failed to download #{key} because #{error.message.presence || error.class}"
        raise_storage_error(error, message:)
      end

      def stat(key)
        object = @helper.object(key)
        # One HEAD: `exists?` would discard its response and `metadata` would
        # send another.
        object.load
        object_info(object, metadata: object.metadata)
      rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
        nil
      rescue *SDK_ERRORS => error
        raise_storage_error(error)
      end

      def list(prefix = "", marker: nil)
        Enumerator
          .new do |objects|
            @helper.list(prefix, marker).each { |object| objects << object_info(object) }
          rescue *SDK_ERRORS => error
            raise_storage_error(error)
          end
          .lazy
      end

      def upload_file(key, source_path, visibility:, headers: {})
        @helper.upload_file(key, source_path, **options(visibility, headers))
        nil
      rescue *SDK_ERRORS => error
        raise_storage_error(error)
      end

      # Legacy backup PUT URLs rely on the bucket's default ACL, not request ACLs.
      def upload_url(key, expires_in:)
        @helper.object(key).presigned_url(:put, expires_in:)
      rescue *SDK_ERRORS => error
        raise_storage_error(error)
      end

      def download_url(key, expires_in:, content_disposition: nil)
        opts = { expires_in: }
        opts[:response_content_disposition] = content_disposition if content_disposition
        @helper.object(key).presigned_url(:get, opts)
      rescue *SDK_ERRORS => error
        raise_storage_error(error)
      end

      def upload_request(key, visibility:, expires_in:, metadata: {})
        url, headers =
          @helper.presigned_request(
            key,
            method: :put_object,
            expires_in:,
            opts: { metadata: }.merge(options(visibility, {})),
          )
        SignedRequest.new(key:, url:, headers:)
      rescue *SDK_ERRORS => error
        raise_storage_error(error)
      end

      def create_multipart(key, content_type, visibility:, metadata: {})
        @helper.create_multipart(key, content_type, metadata:, **options(visibility, {}))
      rescue *SDK_ERRORS => error
        raise_storage_error(error)
      end

      def presign_multipart_part(upload_id:, key:, part_number:)
        @helper.presign_multipart_part(upload_id:, key:, part_number:)
      rescue *SDK_ERRORS => error
        raise_storage_error(error)
      end

      def list_multipart_parts(upload_id:, key:, max_parts: 1000, start_from_part_number: nil)
        response =
          @helper.list_multipart_parts(upload_id:, key:, max_parts:, start_from_part_number:)
        {
          parts:
            response.parts.map do |part|
              { part_number: part.part_number, etag: part.etag, size: part.size }
            end,
          truncated: response.is_truncated,
          next_marker: response.next_part_number_marker,
        }
      rescue *SDK_ERRORS => error
        raise_storage_error(error)
      end

      def complete_multipart(upload_id:, key:, parts:)
        response = @helper.complete_multipart(upload_id:, key:, parts:)
        Result.new(key: response.key, etag: response.etag)
      rescue *SDK_ERRORS => error
        raise_storage_error(error)
      end

      def abort_multipart(upload_id:, key:)
        @helper.abort_multipart(upload_id:, key:)
        nil
      rescue *SDK_ERRORS => error
        raise_storage_error(error)
      end

      private

      def raise_storage_error(error, message: error.message)
        error_class =
          case error
          when Seahorse::Client::NetworkingError
            ConnectionError
          when Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
            CredentialsUnavailable
          when Aws::S3::Errors::NoSuchUpload
            UploadNotFound
          when Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound
            ObjectNotFound
          when Aws::S3::Errors::AccessDenied, Aws::S3::Errors::Forbidden
            AccessDenied
          when Aws::Errors::ServiceError
            ServiceError
          else
            Error
          end
        raise error_class.new(message), cause: error
      end

      def object_info(object, metadata: nil)
        ObjectInfo.new(
          key: object.key,
          size: object.size,
          last_modified: object.last_modified,
          etag: object.etag,
          metadata:,
        )
      end

      def options(visibility, headers)
        if %i[public private bucket_default].exclude?(visibility)
          raise ArgumentError, "Unknown object visibility: #{visibility.inspect}"
        end
        raise ArgumentError, "Unsupported object headers" unless (headers.keys - HEADERS).empty?
        return headers.dup if visibility == :bucket_default

        headers.merge(self.class.visibility_options(visibility))
      end
    end
  end
end
