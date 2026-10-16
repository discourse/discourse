# frozen_string_literal: true

module FileStore
  module ObjectStorage
    ObjectInfo = Data.define(:key, :size, :last_modified, :etag, :metadata)
  end
end
