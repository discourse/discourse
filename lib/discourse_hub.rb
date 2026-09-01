# frozen_string_literal: true

module DiscourseHub
  STATS_FETCHED_AT_KEY = "stats_fetched_at"

  class Error < StandardError
    attr_reader :status, :body

    def initialize(rel_url, status, body)
      @status = status
      @body = body
      super("Discourse Hub (#{rel_url}) returned status #{status}")
    end
  end

  class << self
    def version_check_payload
      default_payload = { installed_version: Discourse::VERSION::STRING }.merge!(
        (
          if Discourse.git_branch == "unknown" && !Rails.env.test?
            {}
          else
            { branch: Discourse.git_branch }
          end
        ),
      )
      default_payload.merge!(get_payload)
    end

    def discourse_version_check
      get("/version_check", version_check_payload)
    end

    def discover_enrollment_payload
      {
        include_in_discourse_discover: SiteSetting.include_in_discourse_discover?,
        forum_url: Discourse.base_url,
        forum_title: SiteSetting.title,
        locale: I18n.locale,
      }
    end

    def discover_enrollment
      post("/discover/enroll", discover_enrollment_payload)
    end

    def stats_fetched_at=(time_with_zone)
      Discourse.redis.set STATS_FETCHED_AT_KEY, time_with_zone.to_i
    end

    def get_payload
      if SiteSetting.share_anonymized_statistics && stats_fetched_at < 7.days.ago
        About.fetch_cached_stats.symbolize_keys
      else
        {}
      end
    end

    def get(rel_url, params = {}, raise_on_error: false)
      singular_action :get, rel_url, params, raise_on_error: raise_on_error
    end

    def post(rel_url, params = {}, raise_on_error: false)
      collection_action :post, rel_url, params, raise_on_error: raise_on_error
    end

    def put(rel_url, params = {}, raise_on_error: false)
      collection_action :put, rel_url, params, raise_on_error: raise_on_error
    end

    def delete(rel_url, params = {}, raise_on_error: false)
      singular_action :delete, rel_url, params, raise_on_error: raise_on_error
    end

    def singular_action(action, rel_url, params = {}, raise_on_error: false)
      connect_opts = connect_opts(params)

      response =
        Excon.public_send(
          action,
          "#{hub_base_url}#{rel_url}",
          {
            headers: {
              "Referer" => referer,
              "Accept" => accepts.join(", "),
            },
            query: params,
          }.merge(connect_opts),
        )

      if raise_on_error && response.status != 200
        raise Error.new(rel_url, response.status, parse_body(response.body))
      end

      JSON.parse(response.body)
    end

    def collection_action(action, rel_url, params = {}, raise_on_error: false)
      connect_opts = connect_opts(params)

      response =
        Excon.public_send(
          action,
          "#{hub_base_url}#{rel_url}",
          {
            body: JSON[params],
            headers: {
              "Referer" => referer,
              "Accept" => accepts.join(", "),
              "Content-Type" => "application/json",
            },
          }.merge(connect_opts),
        )

      if (status = response.status) != 200
        Rails.logger.warn(response_status_log_message(rel_url, status))
      end

      body = parse_body(response.body)

      raise Error.new(rel_url, status, body) if raise_on_error && status != 200

      body
    end

    def parse_body(raw)
      JSON.parse(raw)
    rescue JSON::ParserError
      Rails.logger.error(response_body_log_message(raw))
      nil
    end

    def response_status_log_message(rel_url, status)
      "Discourse Hub (#{hub_base_url}#{rel_url}) returned a bad status #{status}."
    end

    def response_body_log_message(body)
      "Discourse Hub returned a bad response body: #{body}"
    end

    def connect_opts(params = {})
      params.delete(:connect_opts)&.except(:body, :headers, :query) || {}
    end

    def hub_base_url
      if Rails.env.production?
        ENV["HUB_BASE_URL"] || "https://api.discourse.org/api"
      else
        ENV["HUB_BASE_URL"] || "http://local.hub:3000/api"
      end
    end

    def accepts
      %w[application/json application/vnd.discoursehub.v1]
    end

    def referer
      Discourse.base_url
    end

    def stats_fetched_at
      t = Discourse.redis.get(STATS_FETCHED_AT_KEY)
      t ? Time.zone.at(t.to_i) : 1.year.ago
    end
  end
end
