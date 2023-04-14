# frozen_string_literal: true

# This is a patch to avoid the direct use of `Net::HTTP` in the `webpush` gem and instead rely on `FinalDestination::HTTP`
# which protects us from DNS rebinding attacks as well as server side forgery requests.
#
# This patch is considered temporary until we can decide on a longer term solution. In the meantime, we need to patch
# the SSRF vulnerability being exposed by this gem.
module WebPushPatch
  def perform
    http = FinalDestination::HTTP.new(uri.host, uri.port, *proxy_options)
    http.use_ssl = true
    http.ssl_timeout = @options[:ssl_timeout] unless @options[:ssl_timeout].nil?
    http.open_timeout = @options[:open_timeout] unless @options[:open_timeout].nil?
    http.read_timeout = @options[:read_timeout] unless @options[:read_timeout].nil?

    req = FinalDestination::HTTP::Post.new(uri.request_uri, headers)
    req.body = body

    resp = http.request(req)
    verify_response(resp)

    resp
  end
end

klass = defined?(WebPush) ? WebPush : Webpush
klass::Request.prepend(WebPushPatch)
