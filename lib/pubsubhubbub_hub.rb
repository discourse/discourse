require_dependency 'rest_client'

module PubSubHubbubHub

  def self.ping(urls)
    hub_url = SiteSetting.find_by_name('pubsubhubbub_hub').try(:value) || 'https://pubsubhubbub.superfeedr.com/'
    RestClient.post hub_url, :'hub.mode' => 'publish', :'hub.topic' => urls
  end

end
