# frozen_string_literal: true

module FileStore
  module ObjectStorage
    SignedRequest = Data.define(:key, :url, :headers)
  end
end
