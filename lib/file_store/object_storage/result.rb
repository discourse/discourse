# frozen_string_literal: true

module FileStore
  module ObjectStorage
    Result = Data.define(:key, :etag)
  end
end
