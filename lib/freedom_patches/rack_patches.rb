# patch https://github.com/rack/rack/pull/600
#
class Rack::ETag
  private

   def digest_body(body)
    parts = []
    has_body = false

    body.each do |part|
      parts << part
      has_body ||= part.length > 0
    end

    hexdigest =
      if has_body
        digest = Digest::MD5.new
        parts.each { |part| digest << part }
        digest.hexdigest
      end

    [hexdigest, parts]
  end
end

# patch https://github.com/rack/rack/pull/596
#
class Rack::ConditionalGet
  private
   def to_rfc2822(since)
    # shortest possible valid date is the obsolete: 1 Nov 97 09:55 A
    # anything shorter is invalid, this avoids exceptions for common cases
    # most common being the empty string
    if since && since.length >= 16
      # NOTE: there is no trivial way to write this in a non execption way
      #   _rfc2822 returns a hash but is not that usable
      Time.rfc2822(since) rescue nil
    else
      nil
    end
  end
end
