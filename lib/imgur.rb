require 'rest_client'
require 'image_size'

module Imgur

  def self.upload_file(file)

    blob = file.read
    response = RestClient.post(SiteSetting.imgur_endpoint, { image: Base64.encode64(blob) }, { 'Authorization' => "Client-ID #{SiteSetting.imgur_client_id}" })

    json = JSON.parse(response.body)['data'] rescue nil

    return nil if json.blank?

    # Resize the image
    image_info = FastImage.new(file, raise_on_failure: true)
    width, height = ImageSizer.resize(*image_info.size)

    {
      url: json['link'],
      filesize: File.size(file),
      width: width,
      height: height
    }
  end

end
