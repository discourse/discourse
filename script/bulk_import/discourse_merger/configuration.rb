# frozen_string_literal: true

require_relative "artifacts"
require "active_support/core_ext/enumerable"
require "json"
require "yaml"
require "digest"
require "uri"

module BulkImport
  module DiscourseMerge
    class Error < StandardError
    end

    class Configuration
      attr_reader :directory, :data, :sha256

      def initialize(directory, contents: nil)
        @directory = Pathname.new(directory).expand_path
        contents ||= @directory.join("merge.yml").read
        @sha256 = Digest::SHA256.hexdigest(contents)
        @data = YAML.safe_load(contents, permitted_classes: [], aliases: false)
        raise Error, "merge.yml must contain a mapping" unless data.is_a?(Hash)
        known = %w[
          source
          destination
          source_url
          destination_url
          namespace
          source_upload_root
          destination_upload_root
          include_private_messages
          max_category_depth
          category_access
          allow_access_changes
          allowed_missing_topic_ids
          upload_hash_discrepancy_ids
          upload_mode
          preserve_destination_uploads
          preupload_locations
          reviewed_upload_target
          preserved_broken_post_uploads
          preserved_broken_revision_uploads
          import_tags
        ]
        unless (data.keys - known).empty?
          raise Error, "Unknown configuration options: #{data.keys - known}"
        end
        %w[include_private_messages import_tags preserve_destination_uploads].each do |key|
          if [true, false].exclude?(data.fetch(key, true))
            raise Error, "#{key} must be true or false"
          end
        end
        if %w[copy preserve_remote preuploaded].exclude?(upload_mode)
          raise Error, "upload_mode must be copy, preserve_remote, or preuploaded"
        end
        if preserve_destination_uploads? && !preuploaded?
          raise Error, "preserve_destination_uploads requires preuploaded mode"
        end
        unless data.fetch("max_category_depth", 3).is_a?(Integer) &&
                 data.fetch("max_category_depth", 3) > 0
          raise Error, "max_category_depth must be a positive integer"
        end
        %w[source_upload_root destination_upload_root].each do |key|
          next if upload_mode != "copy" && !data.key?(key)
          unless Pathname.new(data.fetch(key)).absolute?
            raise Error, "#{key} must be an absolute path"
          end
        end
        %w[source destination].each do |side|
          database_options(side)
          uri = URI.parse(data.fetch("#{side}_url"))
          unless %w[http https].include?(uri.scheme) && uri.host && !uri.userinfo &&
                   ["", "/"].include?(uri.path) && !uri.query && !uri.fragment
            raise Error, "#{side}_url must be an HTTP origin"
          end
        end
        raise Error, "Source and destination must differ" if data["source"] == data["destination"]
        unless namespace.is_a?(String) && namespace.match?(/\A[a-z][a-z0-9_]*\z/)
          raise Error, "namespace must contain only lowercase letters, numbers and underscores"
        end
      end

      def check_preupload_locations!(target)
        if data.key?("reviewed_upload_target") && data.fetch("reviewed_upload_target") != target
          raise Error,
                "Uploader settings differ from the target confirmed at setup; review the changed settings"
        end
        locations = data["preupload_locations"]
        unless locations.is_a?(Hash) && locations["write"].is_a?(String)
          raise Error,
                "Set preupload_locations.write in merge.yml from the reviewed hosting configuration"
        end
        reads = locations.fetch("read_prefixes", {})
        unless (locations.keys - %w[write read_prefixes]).empty? && reads.is_a?(Hash) &&
                 (reads.keys - %w[source destination]).empty? && reads.values.all?(String)
          raise Error,
                "Check preupload_locations in merge.yml. Use write and optional read_prefixes by side."
        end
        write = "s3://#{target.fetch("bucket")}/#{target.fetch("prefix")}".delete_suffix("/")
        pairs = { "write" => [locations.fetch("write"), write] }
        %w[source destination].each do |side|
          pairs["read_prefixes.#{side}"] = [reads[side], target.dig("read_prefixes", side)]
        end
        pairs.each do |field, (expected, actual)|
          if expected && !expected.match?(%r{\As3://[a-z0-9][a-z0-9.-]+(?:/[\w.-]+)*/?\z})
            raise Error, "Set preupload_locations.#{field} to an S3 bucket and prefix in merge.yml"
          end
          next if expected&.delete_suffix("/") == actual
          raise Error,
                "preupload_locations.#{field} differs: expected #{expected || "(none)"}, resolved #{actual || "(none)"}"
        end
      end

      def connection(side)
        database_options(side).to_h do |key, value|
          if key == "password_env"
            [
              :password,
              ENV.fetch(value) do
                raise Error, "Set #{value} in the merger environment for the #{side} database"
              end,
            ]
          else
            [key.to_sym, value]
          end
        end
      end

      def namespace
        data.fetch("namespace", "incoming")
      end

      def upload_mode
        data.fetch("upload_mode", "copy")
      end

      def preserve_remote?
        upload_mode == "preserve_remote"
      end

      def preuploaded?
        upload_mode == "preuploaded"
      end

      def preserve_destination_uploads?
        data.fetch("preserve_destination_uploads", false)
      end

      def host(side)
        URI
          .parse(data.fetch("#{side}_url"))
          .then { |uri| uri.port == uri.default_port ? uri.host : "#{uri.host}:#{uri.port}" }
      end

      def self.write(path, value)
        Artifacts.write(path, JSON.pretty_generate(value) + "\n")
      end

      private

      def database_options(side)
        supplied = data.fetch(side)
        unless supplied.is_a?(Hash) && supplied["dbname"].is_a?(String) &&
                 !supplied["dbname"].empty?
          raise Error, "#{side} must be a database connection mapping"
        end
        supplied.each do |key, value|
          if %w[dbname host port user password_env sslmode].exclude?(key)
            raise Error, "Unknown #{side} database option: #{key}"
          end
          if key == "password_env" &&
               (!value.is_a?(String) || !value.match?(/\A[A-Za-z_][A-Za-z0-9_]*\z/))
            raise Error, "#{side}.password_env must name an environment variable"
          end
        end
        supplied
      end
    end
  end
end
