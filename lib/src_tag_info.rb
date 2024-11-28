# frozen_string_literal: true

class SrcTagInfo
  def initialize(request)
    @request = request
  end

  def src_tags
    @src_tags ||=
      if src_tag_header = ENV["DISCOURSE_HTTP_SRC_TAG_HEADER"]
        @request.env.fetch("HTTP_#{src_tag_header.upcase.gsub("-", "_")}", "").split()
      else
        []
      end
  end

  def src_tags_supported
    @src_tags_supported ||=
      if src_tag_supported_header = ENV["DISCOURSE_HTTP_SRC_TAG_SUPPORTED_HEADER"]
        @request.env.fetch("HTTP_#{src_tag_supported_header.upcase.gsub("-", "_")}", "").split()
      else
        []
      end
  end

  def verified_crawler
    # Use the source tag metadata to detect whether a request is coming from
    # an address belonging to a known crawler.
    if verified_crawler_src = src_tags&.select { _1.start_with? "crawler-" }
      verified_crawler_src.first&.[](8..)
    else
      nil
    end
  end

  def verified_cloud
    # Use the source tag metadata to detect whether a request is coming from
    # an address belonging to a known cloud provider.
    if verified_cloud_src = src_tags&.select { _1.start_with? "cloud-" }
      verified_cloud_src.first&.[](6..)
    else
      nil
    end
  end
end
