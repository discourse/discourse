# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # An upload referenced by a full URL (`/uploads/…`, `/secure-uploads/…`, or
        # an absolute form on any host) rather than a short `upload://` URL. Older
        # posts store these, and the file dies with the old site unless we carry it
        # over. `sha1` is the upload's sha1, read from the basename (Discourse's
        # filename convention). `original_markdown` is the verbatim source snippet;
        # if the importer can't map the sha1 to a Discourse upload it puts this back
        # unchanged, so a hotlink to some other forum's upload survives as-is.
        UploadUrlReference = Data.define(:sha1, :original_markdown)
      end
    end
  end
end
