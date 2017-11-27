# frozen_string_literal: true

# This module allows us to hijack a request and send it to the client in the deferred job queue
# For cases where we are making remote calls like onebox or proxying files and so on this helps
# free up a unicorn worker while the remote IO is happening
module Hijack

  def hijack(&blk)
    controller_class = self.class
    request = self.request

    if hijack = request.env['rack.hijack']
      io = hijack.call

      Scheduler::Defer.later("hijack work") do

        begin
          # do this first to confirm we have a working connection
          # before doing any work
          io.write "HTTP/1.1 "

          # this trick avoids double render, also avoids any litter that the controller hooks
          # place on the response
          instance = controller_class.new
          response = ActionDispatch::Response.new
          instance.response = response
          instance.request = request

          begin
            instance.instance_eval(&blk)
          rescue => e
            Rails.logger.warn("Failed to process hijacked response correctly #{e}")
          end

          unless instance.response_body
            instance.status = 500
          end

          response.commit!

          body = response.body

          headers = response.headers
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
          io.close
        rescue Errno::EPIPE, IOError
          # happens if client terminated before we responded, ignore
        end
      end
      # not leaked out, we use 418 ... I am a teapot to denote that we are hijacked
      render plain: "", status: 418
    else
      blk.call
    end
  end
end
