# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # An upload referenced by a full URL (`/uploads/…`, `/secure-uploads/…`,
        # or an absolute form on any host) rather than a short `upload://` URL.
        # Older posts store these, and the file is lost with the old site unless
        # we carry it over.
        #
        # `sha1` is the upload's 40-hex sha1: read from the basename for a long
        # URL, decoded from the base62 token for a `/uploads/short-url/…` one.
        # `host` is the URL's host as {UrlOrigin} reads origins, nil for a
        # relative URL. `rest` is the URL's path part. The extractor uses host
        # and path to mark rows the importer maps only against an explicit
        # allowlist, so a foreign-looking sha1 cannot rewrite another site's
        # file on a hash collision (see `RawExtractor#upload_ownership`).
        UploadUrlReference = Data.define(:sha1, :host, :rest)
      end
    end
  end
end
