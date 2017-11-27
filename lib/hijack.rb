# frozen_string_literal: true

# This module allows us to hijack a request and send it to the client in the deferred job queue
# For cases where we are making remote calls like onebox or proxying files and so on this helps
# free up a unicorn worker while the remote IO is happening
module Hijack

  class FakeResponse
    attr_reader :headers
    def initialize
      @headers = {}
    end
  end

  class Binder
    attr_reader :content_type, :body, :status, :response

    def initialize
      @content_type = 'text/plain'
      @status = 500
      @body = ""
      @response = FakeResponse.new
    end

    def immutable_for(duration)
      response.headers['Cache-Control'] = "max-age=#{duration}, public, immutable"
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

      if opts.key?(:content_type)
        @content_type = opts[:content_type]
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

          headers = binder.response.headers
          headers['Content-Length'] = binder.body.bytesize
          headers['Content-Type'] = binder.content_type
          headers['Connection'] = "close"

          io.write "#{binder.status} OK\r\n"

          headers.each do |name, val|
            io.write "#{name}: #{val}\r\n"
          end

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
      binder = Binder.new
      binder.instance_eval(&blk)

      binder.response.headers.each do |name, val|
        response.headers[name] = val
      end

      render(
        body: binder.body,
        content_type: binder.content_type,
        status: binder.status
      )
    end
  end
end
