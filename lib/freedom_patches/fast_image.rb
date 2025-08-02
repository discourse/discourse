# frozen_string_literal: true

class FastImage
  def setup_http
    @http = FinalDestination::HTTP.new(@parsed_uri.host, @parsed_uri.port)
    @http.use_ssl = (@parsed_uri.scheme == "https")
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    @http.open_timeout = @options[:timeout]
    @http.read_timeout = @options[:timeout]
  end
end
