# frozen_string_literal: true

require "file_store/object_storage/error"

module FileStore
  module ObjectStorage
    # The storage service answered and refused the request. Transport and
    # credential failures are plain Errors: callers that turn a refusal into
    # a user-facing response should not hide an outage or a misconfiguration.
    class ServiceError < Error
    end
  end
end
