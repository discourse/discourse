require_dependency 'rest_client'

module PubSubHubbubHub

  def self.ping(urls)
    hub_url = SiteSetting.pubsubhubbub_hub
    if hub_url && (Rails.env == 'production' || ENV['FORCE_PUSH'])
      RestClient.post hub_url, :'hub.mode' => 'publish', :'hub.topic' => urls
    end
  end

end
