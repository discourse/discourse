# frozen_string_literal: true

Asset = Struct.new(:local_path, :local_sha1, :remote_short_url, keyword_init: true)

class LocalDoc
  attr_accessor :path,
                :frontmatter,
                :content,
                :topic_id,
                :first_post_id,
                :remote_content,
                :remote_title,
                :remote_deleted,
                :assets

  def initialize(**kwargs)
    kwargs.each { |k, v| send("#{k}=", v) }
    self.assets ||= []
  end

  def external_id
    "DOC-#{frontmatter["id"]}"
  end

  def section
    path_segments = path.split("/")
    path_segments[0] if path_segments.size > 1
  end

  def content_with_uploads
    unused_assets = assets.dup

    result =
      content.gsub(/![^\]]+\]\(([^)]+)\)/) do |match|
        path = $1
        next match if !path.start_with?("/")

        resolved = File.expand_path("#{__dir__}/../#{path}")
        assets_dir = File.expand_path("#{__dir__}/../assets/")
        raise "Invalid path: #{resolved}" if !resolved.start_with?(assets_dir)

        digest = Digest::SHA1.file(resolved).hexdigest

        asset = assets.find { |a| a.local_sha1 == digest }
        unused_assets.delete(asset)
        if !asset
          puts "  Uploading #{path}..."
          result = API.upload_file(resolved)
          raise "File upload failed: #{result.inspect}" if !result["short_url"]
          asset =
            Asset.new(local_path: path, local_sha1: digest, remote_short_url: result["short_url"])
          assets.push(asset)
        end

        short_url = asset.remote_short_url

        match.gsub(path, short_url)
      end

    unused_assets.each { |asset| assets.delete(asset) }

    result = <<~MD
      #{result}
      
      ---

      <small>This document is version controlled - suggest changes [on github](https://github.com/discourse/discourse-developer-docs/blob/main/docs/#{path}).</small>
    MD

    if assets.size == 0
      result
    else
      <<~MD
        #{result}
        <!-- START DOCS ASSET MAP
        #{serialized_assets}
        END DOCS ASSET MAP -->
      MD
    end
  end

  def serialized_assets
    JSON.pretty_generate(
      assets.map do |asset|
        {
          local_path: asset.local_path,
          local_sha1: asset.local_sha1,
          remote_short_url: asset.remote_short_url
        }
      end
    )
  end

  def remote_content=(value)
    if value.match(/<!-- START DOCS ASSET MAP\n(.+?)\nEND DOCS ASSET MAP -->/m)
      self.assets = JSON.parse($1).map { |raw_asset| Asset.new(**raw_asset) }
    end

    value.gsub!(/![^\]]+\]\(([^)]+)\)/) do |match|
      url = $1
      found_asset = assets.find { |a| a.remote_short_url == url }
      match.sub!(path, found_asset.local_path) if found_asset
      match
    end

    @remote_content = value
  end
end
