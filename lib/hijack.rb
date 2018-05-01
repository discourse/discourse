# frozen_string_literal: true

require_dependency 'method_profiler'

# This module allows us to hijack a request and send it to the client in the deferred job queue
# For cases where we are making remote calls like onebox or proxying files and so on this helps
# free up a unicorn worker while the remote IO is happening
module Hijack

  def hijack(&blk)
    controller_class = self.class

    if hijack = request.env['rack.hijack']

      request.env['discourse.request_tracker.skip'] = true
      request_tracker = request.env['discourse.request_tracker']

      # in the past unicorn would recycle env, this is not longer the case
      env = request.env

      # rack may clean up tempfiles unless we trick it and take control
      tempfiles = env[Rack::RACK_TEMPFILES]
      env[Rack::RACK_TEMPFILES] = nil
      request_copy = ActionDispatch::Request.new(env)

      transfer_timings = MethodProfiler.transfer

      io = hijack.call

      # duplicate headers so other middleware does not mess with it
      # on the way down the stack
      original_headers = response.headers.dup

      Scheduler::Defer.later("hijack #{params["controller"]} #{params["action"]}") do

        MethodProfiler.start(transfer_timings)
        begin
          Thread.current[Logster::Logger::LOGSTER_ENV] = env
          # do this first to confirm we have a working connection
          # before doing any work
          io.write "HTTP/1.1 "

          # this trick avoids double render, also avoids any litter that the controller hooks
          # place on the response
          instance = controller_class.new
          response = ActionDispatch::Response.new
          instance.response = response

          instance.request = request_copy
          original_headers&.each do |k, v|
            instance.response.headers[k] = v
          end

          view_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          begin
            instance.instance_eval(&blk)
          rescue => e
            # TODO we need to reuse our exception handling in ApplicationController
            Discourse.warn_exception(e, message: "Failed to process hijacked response correctly", env: env)
          end
          view_runtime = Process.clock_gettime(Process::CLOCK_MONOTONIC) - view_start

          unless instance.response_body || response.committed?
            instance.status = 500
          end

          response.commit!

          body = response.body

          headers = response.headers
          # add cors if needed
          if cors_origins = env[Discourse::Cors::ORIGINS_ENV]
            Discourse::Cors.apply_headers(cors_origins, env, headers)
          end

          headers['Content-Type'] ||= response.content_type || "text/plain"
          headers['Content-Length'] = body.bytesize
          headers['Connection'] = "close"

          if env[Auth::DefaultCurrentUserProvider::BAD_TOKEN]
            headers['Discourse-Logged-Out'] = '1'
          end

          status_string = Rack::Utils::HTTP_STATUS_CODES[response.status.to_i] || "Unknown"
          io.write "#{response.status} #{status_string}\r\n"

          timings = MethodProfiler.stop
          if timings && duration = timings[:total_duration]
            headers["X-Runtime"] = "#{"%0.6f" % duration}"
          end

          headers.each do |name, val|
            io.write "#{name}: #{val}\r\n"
          end

          io.write "\r\n"
          io.write body
        rescue Errno::EPIPE, IOError
          # happens if client terminated before we responded, ignore
          io = nil
        ensure

          if Rails.configuration.try(:lograge).try(:enabled)
            if timings
              db_runtime = 0
              if timings[:sql]
                db_runtime = timings[:sql][:duration]
              end

              subscriber = Lograge::RequestLogSubscriber.new
              payload = ActiveSupport::HashWithIndifferentAccess.new(
                controller: self.class.name,
                action: action_name,
                params: request.filtered_parameters,
                headers: request.headers,
                format: request.format.ref,
                method: request.request_method,
                path: request.fullpath,
                view_runtime: view_runtime * 1000.0,
                db_runtime: db_runtime * 1000.0,
                timings: timings,
                status: response.status
              )

              event = ActiveSupport::Notifications::Event.new("hijack", Time.now, Time.now + timings[:total_duration], "", payload)
              subscriber.process_action(event)
            end
          end

          MethodProfiler.clear
          Thread.current[Logster::Logger::LOGSTER_ENV] = nil

          io.close if io rescue nil

          if request_tracker
            status = response.status rescue 500
            request_tracker.log_request_info(env, [status, headers || {}, []], timings)
          end

          tempfiles&.each(&:close!)
        end
      end
      # not leaked out, we use 418 ... I am a teapot to denote that we are hijacked
      render plain: "", status: 418
    else
      blk.call
    end
  end
end
