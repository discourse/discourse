# frozen_string_literal: true

# Reads the size of a remote image and whether it is animated with a single
# request, streaming only as many bytes as needed to answer both.
module RemoteImage
  ANIMATABLE_TYPES = %i[gif png webp avif]
  MIN_BYTES_FOR_TYPE = 1.kilobyte
  READ_TIMEOUT = 2

  # FinalDestination#get already handles timeouts and TLS errors
  FETCH_ERRORS = [
    ArgumentError, # malformed or too long urls and redirects
    URI::Error,
    SocketError,
    SystemCallError,
    IOError,
    Net::HTTPBadResponse,
    Zlib::Error,
  ]

  Result = Data.define(:size, :animated, :answered)

  # Returns `[[width, height], animated]`. `animated` is nil when the format
  # can't be animated, and both are nil when the image can't be read.
  def self.size_and_animated(url)
    max_bytes = SiteSetting.max_image_size_kb.kilobytes
    deadline =
      Process.clock_gettime(Process::CLOCK_MONOTONIC) + FinalDestination::MAX_REQUEST_TIME_SECONDS
    buffer = +"".b
    parse_at = 0
    result = nil

    begin
      # validation is skipped to keep fetching images on non-standard ports,
      # FinalDestination::HTTP still guards against SSRF
      FinalDestination
        .new(url, validate_uri: false, timeout: READ_TIMEOUT)
        .get do |_response, chunk, _uri|
          next if chunk.nil?
          buffer << chunk
          throw :done if buffer.bytesize >= max_bytes
          throw :done if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

          # parsing restarts from the first byte, so only retry once the buffer has
          # doubled to keep large GIFs (read past their first frame) linear
          next if buffer.bytesize < parse_at
          parse_at = buffer.bytesize * 2

          result = parse(buffer)
          throw :done if result.answered
        end
    rescue *FETCH_ERRORS
      # keep whatever was read before the request failed
    end

    result = parse(buffer) if !result&.answered
    [result.size, result.animated]
  end

  def self.parse(buffer)
    image = FastImage.new(StringIO.new(buffer))
    size = image.size
    type = image.type

    if !type
      Result.new(size: nil, animated: nil, answered: buffer.bytesize >= MIN_BYTES_FOR_TYPE)
    elsif !size
      Result.new(size: nil, animated: nil, answered: false)
    elsif ANIMATABLE_TYPES.exclude?(type)
      Result.new(size:, animated: nil, answered: true)
    else
      animated = image.animated
      Result.new(size:, animated:, answered: !animated.nil?)
    end
  end
  private_class_method :parse
end
