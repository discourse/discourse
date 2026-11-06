# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      # ZIP layout shared by export and apply:
      #   manifest.json
      #   uploads/<sha1><ext>
      #   themes/<dir>/...
      module Bundle
        FORMAT_VERSION = 1
        MANIFEST = "manifest.json"
        UPLOADS_DIR = "uploads"
        THEMES_DIR = "themes"
      end
    end
  end
end
