# frozen_string_literal: true

module BackupRestore
  # A seekable part buffer lets the SDK retry uploads without retaining the archive.
  class MultipartWriter
    PART_SIZE = 128.megabytes
    MAX_PARTS = 10_000

    def initialize(upload, buffer)
      @upload = upload
      @buffer = buffer
      @parts = []
    end

    def write(data)
      offset = 0
      while offset < data.bytesize
        length = [data.bytesize - offset, PART_SIZE - @buffer.pos].min
        @buffer.write(data.byteslice(offset, length))
        offset += length
        upload_part if @buffer.pos == PART_SIZE
      end
      data.bytesize
    end

    def finish
      upload_part if @buffer.pos > 0 || @parts.empty?
      @upload.complete(multipart_upload: { parts: @parts })
    end

    private

    def upload_part
      if @parts.size >= MAX_PARTS
        raise "Backup exceeds the multipart upload limit of #{MAX_PARTS} parts"
      end

      @buffer.rewind
      number = @parts.size + 1
      response = @upload.part(number).upload(body: @buffer)
      @parts << { part_number: number, etag: response.etag }
      @buffer.rewind
      @buffer.truncate(0)
    end
  end
end
