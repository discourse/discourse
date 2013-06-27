require 'rest_client'

# /!\ WARNING /!\
# This plugin has been extracted from the Discourse source code and has not been tested.
# It really needs some love <3
# /!\ WARNING /!\


module Imgur

  def self.store_file(file, image_info, upload_id)
    raise Discourse::SiteSettingMissing.new("imgur_endpoint")   if SiteSetting.imgur_endpoint.blank?
    raise Discourse::SiteSettingMissing.new("imgur_client_id")  if SiteSetting.imgur_client_id.blank?

    @imgur_loaded = require 'imgur' unless @imgur_loaded

    blob = file.read

    response = RestClient.post(
      SiteSetting.imgur_endpoint,
      { image: Base64.encode64(blob) },
      { 'Authorization' => "ClientID #{SiteSetting.imgur_client_id}" }
    )

    json = JSON.parse(response.body)['data'] rescue nil

    return nil if json.blank?
    return json['link']
  end

end
