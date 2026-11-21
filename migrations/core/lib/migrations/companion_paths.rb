# frozen_string_literal: true

module Migrations
  # Files that live next to the IntermediateDB by default: the files DB the
  # upload run writes, and the cache for files fetched from URLs. `disco upload`
  # and `disco import` derive them the same way, so the two commands agree on
  # where they are without configuring the paths twice.
  module CompanionPaths
    def self.files_db(intermediate_db)
      File.join(File.dirname(intermediate_db), "files.db")
    end

    def self.download_cache_path(intermediate_db)
      File.join(File.dirname(intermediate_db), "downloads")
    end
  end
end
