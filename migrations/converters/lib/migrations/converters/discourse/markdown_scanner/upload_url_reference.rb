# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # An upload referenced by a full URL (`/uploads/…`, `/secure-uploads/…`, or
        # an absolute form on any host) rather than a short `upload://` URL. Older
        # posts store these, and the file dies with the old site unless we carry it
        # over. `sha1` is the upload's sha1, read from the basename (Discourse's
        # filename convention). `host` is the URL's host (normalized the way
        # {UrlOrigin} reads origins), nil for a relative URL — the extractor uses
        # it to mark rows whose host is not the source's own, so the importer maps
        # a foreign-looking sha1 only against an explicit allowlist instead of
        # rewriting another site's file on a hash collision. The verbatim source
        # snippet rides on the embed row (the scanner passes it alongside the
        # node); an unmapped row puts that back unchanged, so a hotlink to some
        # other forum's upload survives as-is.
        UploadUrlReference = Data.define(:sha1, :host)
      end
    end
  end
end
