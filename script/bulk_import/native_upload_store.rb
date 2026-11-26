# frozen_string_literal: true

require "aws-sdk-s3"
require "base64"
require "digest"
require "set"
require "tempfile"
require "uri"

module BulkImport
  # A native backup already has Discourse upload identities. UploadCreator would process
  # the image again and can assign a different identity or change the bytes.
  class NativeUploadStore
    attr_reader :target

    def self.for_preparation(configuration, settings, progress)
      store =
        new(
          settings.fetch(:site_settings),
          read_prefixes: settings.fetch(:preupload_read_prefixes, {}),
        )
      target = store.target
      configuration.check_preupload_locations!(target)
      progress.say(
        "Preparing s3://#{target.fetch("bucket")}/#{target.fetch("prefix")} in #{target.fetch("region")}",
      )
      target
        .fetch("read_prefixes", {})
        .each { |side, path| progress.say("#{side} read prefix: #{path}") }
      acl, tags, key, public_value, private_value = target.fetch("access")
      policy = "ACLs=#{acl}, access-control tags=#{tags}"
      policy += " (key=#{key}, public=#{public_value}, private=#{private_value})" if tags
      progress.say(policy)
      store
    end

    def initialize(settings, client: nil, read_prefixes: {})
      bucket, folder = S3Helper.get_bucket_and_folder_path(settings.fetch(:s3_upload_bucket))
      region = settings.fetch(:s3_region)
      raise ArgumentError, "Set enable_s3_uploads: true" unless settings[:enable_s3_uploads] == true
      unless bucket.match?(/\A[a-z0-9][a-z0-9.-]+\z/) && region.match?(/\A[a-z0-9-]+\z/)
        raise ArgumentError, "Invalid S3 bucket or region"
      end
      if ![true, false].include?(settings.fetch(:multisite, false))
        raise ArgumentError, "multisite must be true or false"
      end
      if settings[:s3_access_key_id].present? != settings[:s3_secret_access_key].present?
        raise ArgumentError, "Supply both S3 credentials or use the AWS credential chain"
      end
      parts = folder.to_s.split("/")
      if settings[:multisite]
        tenant = settings.fetch(:multisite_db_name)
        raise ArgumentError, "Invalid multisite_db_name" unless tenant.match?(/\A[\w-]+\z/)
        parts += ["uploads", tenant]
      end
      unless parts.all? { |part| part.match?(/\A[\w.-]+\z/) && !%w[. ..].include?(part) }
        raise ArgumentError, "Invalid S3 folder"
      end
      suffix =
        (
          if region.start_with?("cn-")
            "s3.#{region}.amazonaws.com.cn"
          else
            "s3.dualstack.#{region}.amazonaws.com"
          end
        )
      cdn = settings[:s3_cdn_url].to_s.delete_suffix("/")
      if !cdn.empty? &&
           !URI
             .parse(cdn)
             .then { |u| u.is_a?(URI::HTTPS) && u.host && !u.userinfo && !u.query && !u.fragment }
        raise ArgumentError, "Invalid HTTPS s3_cdn_url"
      end
      @target = {
        "bucket" => bucket,
        "prefix" => parts.join("/"),
        "region" => region,
        "folder" => folder,
        "origin" => "//#{bucket}.#{suffix}",
        "cdn" => cdn,
      }
      @acl =
        settings.fetch(:s3_use_acls) do
          settings[:s3_enable_access_control_tags] == true ? false : SiteSetting.s3_use_acls
        end
      @tags =
        settings.fetch(:s3_enable_access_control_tags) { SiteSetting.s3_enable_access_control_tags }
      @tag_key =
        settings.fetch(:s3_access_control_tag_key) { SiteSetting.s3_access_control_tag_key }
      @visibility = [
        settings.fetch(:s3_access_control_tag_public_value) do
          SiteSetting.s3_access_control_tag_public_value
        end,
        settings.fetch(:s3_access_control_tag_private_value) do
          SiteSetting.s3_access_control_tag_private_value
        end,
      ]
      if read_prefixes.present?
        @target["read_prefixes"] = read_prefixes.to_h do |side, path|
          uri = URI.parse(path)
          unless %w[source destination].include?(side.to_s) && uri.scheme == "s3" &&
                   uri.host&.match?(/\A[a-z0-9][a-z0-9.-]+\z/) && !uri.userinfo && !uri.query &&
                   !uri.fragment && !uri.port &&
                   uri
                     .path
                     .split("/")
                     .all? { |part| part.match?(/\A[\w.-]*\z/) && !%w[. ..].include?(part) }
            raise ArgumentError, "Invalid preupload_read_prefixes entry"
          end
          [side.to_s, path.delete_suffix("/")]
        end
      end
      @target["access"] = [@acl, @tags, @tag_key, *@visibility]
      if settings[:s3_endpoint].present?
        raise ArgumentError, "Native preparation requires an AWS S3 bucket"
      end
      if [@acl, @tags].any? { |value| ![true, false].include?(value) } ||
           (@tags && ([@tag_key, *@visibility].any?(&:blank?) || @visibility.uniq.size != 2))
        raise ArgumentError, "Check the hosted site's S3 ACL and access-control tag settings"
      end
      @max_age = SiteSetting.s3_max_age
      options = { region: region }
      if settings[:s3_access_key_id].present? || settings[:s3_secret_access_key].present?
        options[:credentials] = Aws::Credentials.new(
          settings.fetch(:s3_access_key_id),
          settings.fetch(:s3_secret_access_key),
          settings[:s3_session_token],
        )
      end
      @client = client || Aws::S3::Client.new(**options)
      @listed_keys = {}
      @listing_lock = Mutex.new
    end

    def check!
      result = @client.head_bucket(bucket: target.fetch("bucket"))
      check_region!(result.bucket_region)
    rescue Aws::S3::Errors::Forbidden, Aws::S3::Errors::AccessDenied => error
      check_region!(error.context.http_response.headers["x-amz-bucket-region"])
      prefix = target.fetch("prefix")
      raise if prefix.empty?
      @client.list_objects_v2(bucket: target.fetch("bucket"), prefix: "#{prefix}/", max_keys: 1)
    end

    def location(relative)
      key = [target["prefix"].presence, relative].compact.join("/")
      "#{target.fetch("origin")}/#{key}"
    end

    def object(relative)
      {
        bucket: target.fetch("bucket"),
        key: [target["prefix"].presence, relative].compact.join("/"),
      }
    end

    def read_backup(prefix, relative, secure, &block)
      uri = URI.parse(prefix)
      key = [uri.path.delete_prefix("/").presence, relative].compact.join("/")
      params = { bucket: uri.host, key: key }
      return false unless head(params)
      check_access!(params, secure)
      read(params, &block)
      true
    end

    def check_access!(params, secure)
      if secure && !@acl && !@tags
        raise "Protected uploads need private ACLs or access-control tags in the hosted bucket"
      end
      if @tags
        tags = @client.get_object_tagging(**params).tag_set
        unless tags.any? { |tag| tag.key == @tag_key && tag.value == @visibility[secure ? 1 : 0] }
          raise "Object access tag differs at #{params[:key]}"
        end
      end
      return unless @acl
      grants = @client.get_object_acl(**params).grants
      shared = grants.select { |grant| grant.grantee.type == "Group" }
      correct =
        if secure
          shared.empty?
        else
          shared.any? do |grant|
            grant.grantee.uri.to_s.end_with?("/AllUsers") && grant.permission == "READ"
          end
        end
      raise "Object access differs at #{params[:key]}" unless correct
    end

    def head(params, known_present: false)
      @client.head_object(**params)
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
      nil
    rescue Aws::S3::Errors::Forbidden, Aws::S3::Errors::AccessDenied
      raise if known_present
      prefix = configured_listing_prefix(params)
      raise unless prefix
      raise if listed_keys(params.fetch(:bucket), prefix).include?(params.fetch(:key))
      nil
    end

    def read(params, &block)
      @client.get_object(**params, &block)
    end

    def digests(params)
      sha1, sha256 = Digest::SHA1.new, Digest::SHA256.new
      read(params) do |data|
        sha1 << data
        sha256 << data
      end
      [sha1.hexdigest, sha256.hexdigest]
    end

    def create(params, file, filename, secure, sha256)
      raise "Protected upload requires access controls" if secure && !@tags && !@acl
      options = {
        content_type:
          MiniMime.lookup_by_filename(filename)&.content_type || "application/octet-stream",
        content_disposition: FileStore::S3Store.content_disposition_for(filename),
        cache_control: "max-age=#{@max_age}, public, immutable",
      }
      options[:acl] = secure ? "private" : "public-read" if @acl
      options[:tagging] = URI.encode_www_form(@tag_key => @visibility[secure ? 1 : 0]) if @tags
      File.open(file, "rb") do |stream|
        if stream.size <= 64.megabytes
          @client.put_object(
            **params,
            **options,
            body: stream,
            if_none_match: "*",
            checksum_sha256: Base64.strict_encode64([sha256].pack("H*")),
          )
        else
          multipart(params, options, stream, sha256)
        end
      end
    rescue Aws::S3::Errors::PreconditionFailed
      # Another worker created this key; the caller verifies its bytes and access.
      nil
    end

    private

    def check_region!(region)
      if region.present? && region != target.fetch("region")
        raise ArgumentError, "Bucket region differs from s3_region"
      end
    end

    def configured_listing_prefix(params)
      scopes = [[target.fetch("bucket"), target.fetch("prefix")]]
      target
        .fetch("read_prefixes", {})
        .each_value do |value|
          uri = URI.parse(value)
          scopes << [uri.host, uri.path.delete_prefix("/")]
        end
      scopes
        .filter_map do |bucket, prefix|
          if bucket == params.fetch(:bucket) && prefix.present? &&
               params.fetch(:key).start_with?("#{prefix}/")
            "#{prefix}/"
          end
        end
        .max_by(&:length)
    end

    def listed_keys(bucket, prefix)
      # Prefix-restricted roles can receive 403 for missing keys. List each
      # configured prefix once to establish absence without broadening access.
      # Conditional writes and a fresh HEAD still guard concurrent creation.
      @listing_lock.synchronize do
        @listed_keys[[bucket, prefix]] ||= Set.new.tap do |keys|
          @client
            .list_objects_v2(bucket: bucket, prefix: prefix)
            .each_page { |page| page.contents.each { |object| keys.add(object.key) } }
        end
      end
    end

    def multipart(params, options, stream, sha256)
      id =
        @client.create_multipart_upload(**params, **options, checksum_algorithm: "SHA256").upload_id
      parts = []
      digest = Digest::SHA256.new
      size = [16.megabytes, (stream.size / 9999.0).ceil].max
      while (data = stream.read(size))
        digest << data
        number = parts.size + 1
        checksum = Digest::SHA256.base64digest(data)
        part =
          @client.upload_part(
            **params,
            upload_id: id,
            part_number: number,
            body: data,
            checksum_sha256: checksum,
          )
        parts << { part_number: number, etag: part.etag, checksum_sha256: checksum }
      end
      raise "Local bytes changed during multipart upload" unless digest.hexdigest == sha256
      result =
        @client.complete_multipart_upload(
          **params,
          upload_id: id,
          multipart_upload: {
            parts: parts,
          },
          if_none_match: "*",
        )
      id = nil
      result
    ensure
      @client.abort_multipart_upload(**params, upload_id: id) if id
    end
  end
end
