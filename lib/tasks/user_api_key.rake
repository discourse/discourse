# frozen_string_literal: true

require "base64"
require "cgi"
require "fileutils"
require "json"
require "net/http"
require "net/https"
require "openssl"
require "securerandom"
require "uri"

module UserApiKeyDeviceAuthRake
  class << self
    def run
      if ENV["HELP"].present?
        puts usage
        return
      end

      site =
        (ENV["SITE"].presence || Discourse.base_url.presence || "http://localhost:3000").chomp("/")
      scopes = ENV.fetch("SCOPES", "read")
      application_name = ENV.fetch("APPLICATION_NAME", "Discourse user API key device auth test")
      client_id = ENV.fetch("CLIENT_ID", "discourse-rake-device-auth")
      padding = ENV.fetch("PADDING", "oaep")
      poll_interval = ENV.fetch("POLL_INTERVAL", "5").to_i
      timeout = ENV.fetch("TIMEOUT", "600").to_i
      verify = ENV.fetch("VERIFY", "1") != "0"
      verbose = verbose?
      expires_in_seconds = requested_expiry_seconds

      private_key = OpenSSL::PKey::RSA.new(2048)
      nonce = SecureRandom.hex
      request_body = {
        application_name: application_name,
        client_id: client_id,
        scopes: scopes,
        public_key: private_key.public_key.to_pem,
        nonce: nonce,
        padding: padding,
      }
      request_body[:expires_in_seconds] = expires_in_seconds if expires_in_seconds

      _, device_response =
        json_request(:post, url_for(site, "/user-api-key/device.json"), body: request_body)
      interval = [poll_interval, device_response["interval"].to_i].max

      device_url =
        device_response["verification_uri_with_request"] || device_response["verification_uri"]

      device_code = device_response["device_code"]
      abort "Device authorization response did not include a device_code." if device_code.blank?
      fingerprint = device_code_fingerprint(device_code)

      puts "Open this URL in your browser: #{device_url}"
      puts "Enter this code when prompted: #{device_response["user_code"]}"
      log("Device code fingerprint: #{fingerprint} (matches verbose server logs)", verbose: verbose)
      puts "Waiting for authorization..."

      payload =
        poll_for_payload(
          site,
          device_code,
          interval,
          timeout,
          verbose: verbose,
          device_code_fingerprint: fingerprint,
        )
      decrypted_payload = decrypt_payload(payload, private_key, padding)

      if decrypted_payload["nonce"] != nonce
        abort "The encrypted payload nonce did not match the request nonce."
      end

      result = {
        site: site,
        user_api_key: decrypted_payload.fetch("key"),
        user_api_client_id: client_id,
        scopes: scopes.split(","),
        expires_at: decrypted_payload["expires_at"],
      }

      result[:verified] = verify_key(site, result[:user_api_key], client_id) if verify
      write_profile(ENV["OUTPUT"], site, result[:user_api_key], client_id) if ENV["OUTPUT"].present?

      puts JSON.pretty_generate(result)
    end

    def usage
      <<~TEXT
        Request a User API Key using the device authorization flow.

        Usage:
          bin/rake user_api_key:device_auth [SITE=http://localhost:3000] [SCOPES=read,write] [EXPIRES_IN=1d]

        Environment variables:
          SITE                 Discourse site URL. Defaults to Discourse.base_url.
          SCOPES               Comma-separated scopes. Defaults to read.
          APPLICATION_NAME     Name shown to the authorizing user.
          CLIENT_ID            User API client id. Defaults to discourse-rake-device-auth.
          EXPIRES_IN           Human duration, e.g. 1d, 12h, 30m, or integer seconds.
          EXPIRES_IN_SECONDS   Exact expiry duration in seconds. Overrides EXPIRES_IN.
          PADDING              RSA padding mode. Defaults to oaep.
          OUTPUT               Optional path for a profile JSON file.
          POLL_INTERVAL        Poll interval in seconds. Defaults to 5.
          TIMEOUT              Poll timeout in seconds. Defaults to 600.
          VERIFY               Set to 0 to skip /session/current.json verification.
          VERBOSE              Set to 1 to print poll attempts, status changes, and correlation IDs.
          HELP                 Set to 1 to show this help.
      TEXT
    end

    def verbose?
      ENV["VERBOSE"] == "1"
    end

    def log(message, verbose: verbose?)
      puts message if verbose
    end

    def device_code_fingerprint(device_code)
      UserApiKey::DeviceAuth.trace_id_for(device_code)
    end

    def requested_expiry_seconds
      if ENV["EXPIRES_IN_SECONDS"].present?
        seconds = Integer(ENV["EXPIRES_IN_SECONDS"], 10)
        abort "EXPIRES_IN_SECONDS must be positive." if seconds <= 0
        return seconds
      end

      parse_duration(ENV["EXPIRES_IN"]) if ENV["EXPIRES_IN"].present?
    rescue ArgumentError
      abort "EXPIRES_IN_SECONDS must be an integer number of seconds."
    end

    def parse_duration(value)
      duration = value.to_s.strip.downcase
      if duration.match?(/\A\d+\z/)
        seconds = Integer(duration, 10)
        abort "EXPIRES_IN must be positive." if seconds <= 0
        return seconds
      end

      match = duration.match(/\A(\d+)([smhd])\z/)
      if match.blank?
        abort "EXPIRES_IN must be an integer number of seconds or a duration like 1d, 12h, or 30m."
      end

      amount = match[1].to_i
      multiplier = { "s" => 1, "m" => 60, "h" => 3600, "d" => 86_400 }.fetch(match[2])
      seconds = amount * multiplier
      abort "EXPIRES_IN must be positive." if seconds <= 0
      seconds
    end

    def url_for(site, path, query = nil)
      uri = URI("#{site.chomp("/")}/#{path.sub(%r{\A/}, "")}")
      uri.query = URI.encode_www_form(query) if query.present?
      uri
    end

    def json_request(method, uri, body: nil, headers: {})
      request =
        case method
        when :get
          Net::HTTP::Get.new(uri)
        when :post
          Net::HTTP::Post.new(uri)
        else
          raise ArgumentError, "Unsupported HTTP method: #{method}"
        end

      request["Accept"] = "application/json"
      headers.each { |name, value| request[name] = value }

      if body
        request.content_type = "application/json"
        request.body = JSON.generate(body)
      end

      response =
        Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(request)
        end

      parsed = response.body.present? ? JSON.parse(response.body) : {}
      unless response.is_a?(Net::HTTPSuccess)
        abort "Request to #{uri} failed with HTTP #{response.code}: #{response.body}"
      end

      [response, parsed]
    rescue JSON::ParserError
      abort "Request to #{uri} did not return JSON: #{response&.body}"
    rescue Errno::ECONNREFUSED, SocketError, OpenSSL::SSL::SSLError => e
      abort "Request to #{uri} failed: #{e.message}"
    end

    def poll_for_payload(site, device_code, interval, timeout, verbose:, device_code_fingerprint:)
      started_at = Time.now
      deadline = started_at + timeout
      attempt = 0
      previous_status = nil

      loop do
        if Time.now >= deadline
          abort "Timed out waiting for authorization#{correlation_suffix(device_code_fingerprint)}."
        end

        attempt += 1
        _, response =
          json_request(
            :post,
            url_for(site, "/user-api-key/device/poll.json"),
            body: {
              device_code: device_code,
            },
          )

        status = response["status"]
        log_poll_attempt(
          attempt: attempt,
          status: status,
          previous_status: previous_status,
          started_at: started_at,
          deadline: deadline,
          interval: interval,
          device_code_fingerprint: device_code_fingerprint,
          verbose: verbose,
        )
        previous_status = status

        case status
        when UserApiKey::DeviceAuth::POLL_STATUS_AUTHORIZATION_PENDING
          sleep interval
        when UserApiKey::DeviceAuth::POLL_STATUS_AUTHORIZED
          return response.fetch("payload")
        when UserApiKey::DeviceAuth::POLL_STATUS_ACCESS_DENIED
          abort "The authorization request was denied#{correlation_suffix(device_code_fingerprint)}."
        when UserApiKey::DeviceAuth::POLL_STATUS_EXPIRED_TOKEN
          abort "The device authorization request expired#{correlation_suffix(device_code_fingerprint)}."
        else
          abort "Unexpected device authorization status: #{status.inspect}#{correlation_suffix(device_code_fingerprint)}."
        end
      end
    end

    def log_poll_attempt(
      attempt:,
      status:,
      previous_status:,
      started_at:,
      deadline:,
      interval:,
      device_code_fingerprint:,
      verbose:
    )
      return if !verbose

      elapsed = (Time.now - started_at).round(1)
      remaining = [deadline - Time.now, 0].max.round(1)
      transition =
        previous_status.present? && previous_status != status ? " (was #{previous_status})" : ""
      puts "Poll ##{attempt}: status=#{status.inspect}#{transition}, elapsed=#{elapsed}s, remaining=#{remaining}s, next_interval=#{interval}s, device_code_hash=#{device_code_fingerprint}"
    end

    def correlation_suffix(device_code_fingerprint)
      " (device_code_hash=#{device_code_fingerprint})"
    end

    def decrypt_payload(payload, private_key, padding)
      encrypted = Base64.decode64(payload)
      decrypted =
        if padding == "oaep"
          private_key.private_decrypt(encrypted, OpenSSL::PKey::RSA::PKCS1_OAEP_PADDING)
        else
          private_key.private_decrypt(encrypted)
        end

      JSON.parse(decrypted)
    end

    def verify_key(site, key, client_id)
      _, response =
        json_request(
          :get,
          url_for(site, "/session/current.json"),
          headers: {
            "User-Api-Key" => key,
            "User-Api-Client-Id" => client_id,
          },
        )

      response["current_user"].present?
    end

    def write_profile(path, site, key, client_id)
      profile = { auth_pairs: [{ site: site, user_api_key: key, user_api_client_id: client_id }] }

      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
        file.write(JSON.pretty_generate(profile))
      end
      File.chmod(0o600, path)
      puts "Wrote profile to #{path}"
    end
  end
end

namespace :user_api_key do
  desc "Request a User API Key using the device authorization flow"
  task device_auth: :environment do
    UserApiKeyDeviceAuthRake.run
  end
end
