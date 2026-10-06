# frozen_string_literal: true

module BackupRestore
  # Seekable buffers let the SDK retry individual parts without retaining the archive.
  class MultipartWriter
    PART_SIZE = 128.megabytes
    MAX_PARTS = 10_000

    def self.open(upload, logger: nil)
      Dir.mktmpdir("backup-multipart-") do |directory|
        writer = new(upload, directory, logger)
        begin
          writer.start
          yield writer
        ensure
          writer.close
        end
      end
    end

    def initialize(upload, directory, logger)
      @upload = upload
      @directory = directory
      @logger = logger
      @concurrency = [GlobalSetting.backup_s3_upload_concurrency.to_i, 1].max
      @buffers = []
      @available = Queue.new
      @pending = Queue.new
      @completed = Queue.new
      @errors = Queue.new
      @workers = []
      @parts = []
      @part_number = 0
      @buffer_wait = 0.0
      @upload_seconds = []
    end

    def start
      # One buffer per worker plus one for the archive producer; no unbounded backlog.
      (@concurrency + 1).times do |index|
        buffer = File.open(File.join(@directory, "part-#{index}"), "w+b")
        @buffers << buffer
        @available << buffer
      end
      @logger&.call(
        "Uploading S3 parts with #{@concurrency} workers (#{PART_SIZE / 1.megabyte} MiB per part)...",
      )
      Thread.handle_interrupt(Exception => :never) do
        @concurrency.times do
          @workers << Thread.new do
            Thread.handle_interrupt(Exception => :immediate) { upload_parts }
          end
        end
      end
    end

    def write(data)
      raise_upload_error
      offset = 0
      while offset < data.bytesize
        @buffer ||= acquire_buffer
        length = [data.bytesize - offset, PART_SIZE - @buffer.pos].min
        @buffer.write(data.byteslice(offset, length))
        offset += length
        enqueue_part if @buffer.pos == PART_SIZE
      end
      data.bytesize
    end

    def finish
      @buffer ||= acquire_buffer if @part_number == 0
      enqueue_part if @buffer && (@buffer.pos > 0 || @part_number == 0)
      @pending.close
      @workers.each(&:join)
      raise_upload_error
      collect_completed_parts
      @upload.complete(multipart_upload: { parts: @parts.sort_by { |part| part[:part_number] } })
      @logger&.call(
        "Finished S3 multipart upload: #{@parts.size} parts; " \
          "average part upload #{format("%.2f", @upload_seconds.sum / @upload_seconds.size)}s, " \
          "slowest #{format("%.2f", @upload_seconds.max)}s; " \
          "waiting for a free buffer #{format("%.2f", @buffer_wait)}s",
      )
    end

    def close
      Thread.handle_interrupt(Exception => :never) do
        @pending.clear
        @pending.close
        @workers.each(&:join)
        @buffers.each(&:close)
      end
    end

    private

    def acquire_buffer
      raise_upload_error
      started = monotonic_time
      buffer = @available.pop
      @buffer_wait += monotonic_time - started
      collect_completed_parts
      raise_upload_error
      buffer
    end

    def enqueue_part
      raise_upload_error
      if @part_number >= MAX_PARTS
        raise "Backup exceeds the multipart upload limit of #{MAX_PARTS} parts"
      end
      @part_number += 1
      @buffer.rewind
      @pending << [@part_number, @buffer]
      @buffer = nil
    end

    def upload_parts
      while (job = @pending.pop)
        break if @failure || !@errors.empty?
        number, buffer = job
        begin
          started = monotonic_time
          response = @upload.part(number).upload(body: buffer)
          @completed << [number, response.etag, monotonic_time - started]
          buffer.rewind
          buffer.truncate(0)
        rescue Exception => error
          @errors << error
          return
        ensure
          @available << buffer
        end
      end
    rescue Exception => error
      @errors << error
    end

    def collect_completed_parts
      until @completed.empty?
        number, etag, seconds = @completed.pop
        @parts << { part_number: number, etag: etag }
        @upload_seconds << seconds
        if @parts.size % 10 == 0
          @logger&.call(
            "Uploaded #{@parts.size} S3 parts; latest part #{number} took #{format("%.2f", seconds)}s; waiting for buffers #{format("%.2f", @buffer_wait)}s",
          )
        end
      end
    end

    def raise_upload_error
      @failure ||= @errors.pop unless @errors.empty?
      raise @failure if @failure
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
