# frozen_string_literal: true

# This module allows us to hijack a request and send it to the client in the deferred job queue
# For cases where we are making remote calls like onebox or proxying files and so on this helps
# free up a unicorn worker while the remote IO is happening
module Hijack

  def hijack(&blk)
    controller_class = self.class

    if hijack = request.env['rack.hijack']

      request.env['discourse.request_tracker.skip'] = true
      request_tracker = request.env['discourse.request_tracker']

      # unicorn will re-cycle env, this ensures we keep the original copy
      env_copy = request.env.dup
      request_copy = ActionDispatch::Request.new(env_copy)

      transfer_timings = MethodProfiler.transfer if defined? MethodProfiler

      io = hijack.call

      Scheduler::Defer.later("hijack #{params["controller"]} #{params["action"]}") do

        MethodProfiler.start(transfer_timings) if defined? MethodProfiler

        begin
          Thread.current[Logster::Logger::LOGSTER_ENV] = env_copy
          # do this first to confirm we have a working connection
          # before doing any work
          io.write "HTTP/1.1 "

          # this trick avoids double render, also avoids any litter that the controller hooks
          # place on the response
          instance = controller_class.new
          response = ActionDispatch::Response.new
          instance.response = response

          instance.request = request_copy

          begin
            instance.instance_eval(&blk)
          rescue => e
            # TODO we need to reuse our exception handling in ApplicationController
            Discourse.warn_exception(e, message: "Failed to process hijacked response correctly", env: env_copy)
          end

          unless instance.response_body || response.committed?
            instance.status = 500
          end

          response.commit!

          body = response.body

          headers = response.headers
          # add cors if needed
          if cors_origins = env_copy[Discourse::Cors::ORIGINS_ENV]
            Discourse::Cors.apply_headers(cors_origins, env_copy, headers)
          end

          headers['Content-Length'] = body.bytesize
          headers['Content-Type'] = response.content_type || "text/plain"
          headers['Connection'] = "close"

          status_string = Rack::Utils::HTTP_STATUS_CODES[instance.status.to_i] || "Unknown"
          io.write "#{instance.status} #{status_string}\r\n"

          headers.each do |name, val|
            io.write "#{name}: #{val}\r\n"
          end

          io.write "\r\n"
          io.write body
        rescue Errno::EPIPE, IOError
          # happens if client terminated before we responded, ignore
          io = nil
        ensure

          Thread.current[Logster::Logger::LOGSTER_ENV] = nil

          io.close if io rescue nil

          if request_tracker
            status = instance.status rescue 500
            timings = MethodProfiler.stop if defined? MethodProfiler
            request_tracker.log_request_info(env_copy, [status, headers || {}, []], timings)
          end
        end
      end
      # not leaked out, we use 418 ... I am a teapot to denote that we are hijacked
      render plain: "", status: 418
    else
      blk.call
    end
  end
end
