# frozen_string_literal: true

# This module allows us to hijack a request and send it to the client in the deferred job queue
# For cases where we are making remote calls like onebox or proxying files and so on this helps
# free up a unicorn worker while the remote IO is happening
module Hijack
  class Binder
    attr_reader :content_type, :body, :status

    def initialize
      @content_type = 'text/plain'
      @status = 500
      @body = ""
    end

    def render(opts)
      if opts[:status]
        @status = opts[:status].to_i
      else
        @status = 200
      end

      if opts.key?(:body)
        @body = opts[:body].to_s
      end

      if opts.key?(:plain)
        @content_type = 'text/plain; charset=utf-8'
        @body = opts[:plain].to_s
      end

      if opts.key?(:json)
        @content_type = 'application/json; charset=utf-8'
        @body = opts[:json]
        unless String === @body
          @body = @body.to_json
        end
      end
    end
  end

  def hijack(&blk)
    if hijack = request.env['rack.hijack']
      io = hijack.call

      Scheduler::Defer.later("hijack work") do

        begin
          # do this first to confirm we have a working connection
          # before doing any work
          io.write "HTTP/1.1 "

          binder = Binder.new
          begin
            binder.instance_eval(&blk)
          rescue => e
            Rails.logger.warn("Failed to process hijacked response correctly #{e}")
          end

          io.write "#{binder.status} OK\r\n"
          io.write "Content-Length: #{binder.body.bytesize}\r\n"
          io.write "Content-Type: #{binder.content_type}\r\n"
          io.write "Connection: close\r\n"
          io.write "\r\n"
          io.write binder.body
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
