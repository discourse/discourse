require_dependency 'version'
require_dependency 'site_setting'

module DiscourseHub

  STATS_FETCHED_AT_KEY = "stats_fetched_at"

  def self.version_check_payload
    default_payload = { installed_version: Discourse::VERSION::STRING }.merge!(Discourse.git_branch == "unknown" ? {} : { branch: Discourse.git_branch })
    default_payload.merge!(get_payload)
  end

  def self.discourse_version_check
    get('/version_check', version_check_payload)
  end

  def self.stats_fetched_at=(time_with_zone)
    $redis.set STATS_FETCHED_AT_KEY, time_with_zone.to_i
  end

  def self.get_payload
    SiteSetting.share_anonymized_statistics && stats_fetched_at < 7.days.ago ? About.fetch_cached_stats.symbolize_keys : {}
  end

  def self.get(rel_url, params = {})
    singular_action :get, rel_url, params
  end

  def self.post(rel_url, params = {})
    collection_action :post, rel_url, params
  end

  def self.put(rel_url, params = {})
    collection_action :put, rel_url, params
  end

  def self.delete(rel_url, params = {})
    singular_action :delete, rel_url, params
  end

  def self.singular_action(action, rel_url, params = {})
    connect_opts = connect_opts(params)
    JSON.parse(Excon.send(action,
      "#{hub_base_url}#{rel_url}",
      {
        headers: { 'Referer' => referer, 'Accept' => accepts.join(', ') },
        query: params,
        omit_default_port: true
      }.merge(connect_opts)
    ).body)
  end

  def self.collection_action(action, rel_url, params = {})
    connect_opts = connect_opts(params)

    response = Excon.send(action,
      "#{hub_base_url}#{rel_url}",
      {
        body: JSON[params],
        headers: { 'Referer' => referer, 'Accept' => accepts.join(', '), "Content-Type" => "application/json" },
        omit_default_port: true
      }.merge(connect_opts)
    )

    if (status = response.status) != 200
      Rails.logger.warn(response_status_log_message(rel_url, status))
    end

    begin
      JSON.parse(response.body)
    rescue JSON::ParserError
      Rails.logger.error(response_body_log_message(response.body))
    end
  end

  def self.response_status_log_message(rel_url, status)
    "Discourse Hub (#{hub_base_url}#{rel_url}) returned a bad status #{status}."
  end

  def self.response_body_log_message(body)
    "Discourse Hub returned a bad response body: #{body}"
  end

  def self.connect_opts(params = {})
    params.delete(:connect_opts)&.except(:body, :headers, :query) || {}
  end

  def self.hub_base_url
    if Rails.env.production?
      ENV['HUB_BASE_URL'] || 'https://api.discourse.org/api'
    else
      ENV['HUB_BASE_URL'] || 'http://local.hub:3000/api'
    end
  end

  def self.accepts
    ['application/json', 'application/vnd.discoursehub.v1']
  end

  def self.referer
    Discourse.base_url
  end

  def self.stats_fetched_at
    t = $redis.get(STATS_FETCHED_AT_KEY)
    t ? Time.zone.at(t.to_i) : 1.year.ago
  end

end
