require 'rest_client'
require 'image_size'

module Imgur

  def self.upload_file(file)

    blob = file.read
    response = RestClient.post(SiteSetting.imgur_endpoint, key: SiteSetting.imgur_api_key, image: Base64.encode64(blob))

    json = JSON.parse(response.body)['upload'] rescue nil

    return nil if json.blank?

    # Resize the image
    json['image']['width'], json['image']['height'] = ImageSizer.resize(json['image']['width'], json['image']['height'])

    {url: json['links']['original'],
     filesize: json['image']['size'],
     width: json['image']['width'],
     height: json['image']['height']}
  end

end
