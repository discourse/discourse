# frozen_string_literal: true

# since all the rescue from clauses are not caught by the application controller for matches
# we need to handle certain exceptions here
module Middleware
  class DiscoursePublicExceptions < ::ActionDispatch::PublicExceptions
    INVALID_REQUEST_ERRORS = Set.new([
      Rack::QueryParser::InvalidParameterError,
      ActionController::BadRequest,
      ActionDispatch::Http::Parameters::ParseError,
    ])

    def initialize(path)
      super
    end

    def call(env)
      # this is so so gnarly
      # sometimes we leak out exceptions prior to creating a controller instance
      # this can happen if we have an exception in a route constraint in some cases
      # this code re-dispatches the exception to our application controller so we can
      # properly translate the exception to a page
      exception = env["action_dispatch.exception"]
      response = ActionDispatch::Response.new

      exception = nil if INVALID_REQUEST_ERRORS.include?(exception)

      if exception
        begin
          fake_controller = ApplicationController.new
          fake_controller.response = response
          fake_controller.request = request = ActionDispatch::Request.new(env)

          # We can not re-dispatch bad mime types
          begin
            request.format
          rescue Mime::Type::InvalidMimeType
            return [400, { "Cache-Control" => "private, max-age=0, must-revalidate" }, ["Invalid MIME type"]]
          end

          # Or badly formatted multipart requests
          begin
            request.POST
          rescue EOFError
            return [400, { "Cache-Control" => "private, max-age=0, must-revalidate" }, ["Invalid request"]]
          end

          if ApplicationController.rescue_with_handler(exception, object: fake_controller)
            body = response.body
            if String === body
              body = [body]
            end
            return [response.status, response.headers, body]
          end
        rescue => e
          return super if INVALID_REQUEST_ERRORS.include?(e.class)
          Discourse.warn_exception(e, message: "Failed to handle exception in exception app middleware")
        end

      end
      super
    end

  end
end
