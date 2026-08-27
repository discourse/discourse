# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # An upload referenced by a full URL (`/uploads/…`, `/secure-uploads/…`, or
        # an absolute form on any host) rather than a short `upload://` URL. Older
        # posts store these, and the file dies with the old site unless we carry it
        # over. `sha1` is the upload's 40-hex sha1: read from the basename for a
        # long URL, decoded from the base62 token for a `/uploads/short-url/…`
        # one. `host` is the URL's host (normalized the way {UrlOrigin} reads
        # origins), nil for a relative URL. `rest` is the URL's path part, so the
        # extractor can check it against a configured path prefix: on a
        # subdirectory install, `/other/uploads/…` on the same host belongs to a
        # different application, and its sha1 must not be treated as the
        # source's own. The extractor uses both to mark rows the importer maps
        # only against an explicit allowlist, so a foreign-looking sha1 cannot
        # rewrite another site's file on a hash collision. The verbatim source
        # snippet rides on the embed row (the scanner passes it alongside the
        # node); an unmapped row puts that back unchanged, so a hotlink to some
        # other forum's upload survives as-is.
        UploadUrlReference = Data.define(:sha1, :host, :rest)
      end
    end
  end
end
