# frozen_string_literal: true

require "file_store/object_storage/service_error"

module FileStore
  module ObjectStorage
    class ObjectNotFound < ServiceError
    end
  end
end
