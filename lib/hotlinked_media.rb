# frozen_string_literal: true

# Primitives shared by the post- and chat-side hotlinked media jobs: finding
# candidate media in cooked HTML, and downloading it into an Upload with the
# status that gets recorded against the target.
module HotlinkedMedia
  # Nodes in +html+ whose media may be hotlinked. Avatars and lightbox thumbnails
  # are skipped: the former are never hotlinked, the latter duplicate the link
  # that wraps them.
  class << self
    def extract_candidates(html)
      doc = html.is_a?(Nokogiri::XML::Node) ? html : Nokogiri::HTML5.fragment(html)

      doc.css("img[src], [#{PrettyText::BLOCKED_HOTLINKED_SRC_ATTR}], a.lightbox[href]") -
        doc.css("img.avatar") - doc.css(".lightbox img[src]")
    end

    # The src to download for +node+: normalized without dropping the scheme, then
    # given one if it was protocol-relative.
    def download_src_for(node)
      original_src = node["src"] || node[PrettyText::BLOCKED_HOTLINKED_SRC_ATTR] || node["href"]
      return original_src if original_src.blank?

      src = PostHotlinkedMedia.normalize_src(original_src, reset_scheme: false)
      src =
        "#{SiteSetting.force_https ? "https" : "http"}:#{original_src}" if original_src.start_with?(
        "//",
      )
      src
    end

    # Whether +src+ points somewhere this site does not serve, and so is a
    # candidate for downloading. Cheap by design: no database or network access.
    def remote_src?(src)
      return false if src.blank?
      return false if src.downcase.start_with?("data:")
      return false if src.start_with?("/") && !src.start_with?("//")
      return false if Discourse.store.has_been_uploaded?(src)

      !PostHotlinkedMedia.normalize_src(src).start_with?(*local_bases)
    end

    # Downloads +src+ for +user_id+, returning [status, upload]. The status is the
    # one to record against the target; upload is nil unless it is :downloaded.
    def download(src, user_id, tmp_file_name:)
      [:downloaded, HotlinkedMediaDownloader.download(src, user_id, tmp_file_name:)]
    rescue HotlinkedMediaDownloader::ImageTooLargeError
      [:too_large, nil]
    rescue HotlinkedMediaDownloader::ImageBrokenError
      [:download_failed, nil]
    rescue HotlinkedMediaDownloader::UploadCreateError
      [:upload_create_failed, nil]
    end

    private

    def local_bases
      [
        Discourse.base_url.presence,
        Discourse.asset_host.presence,
        SiteSetting.external_emoji_url.presence,
      ].compact.map { |base| PostHotlinkedMedia.normalize_src(base) }
    end
  end
end
