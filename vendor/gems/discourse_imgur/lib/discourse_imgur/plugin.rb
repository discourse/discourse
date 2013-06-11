require 'discourse_plugin'

# /!\ WARNING /!\
# This plugin has been extracted from the Discourse source code and has not been tested.
# It really needs some love <3
# /!\ WARNING /!\

module DiscourseImgur

  class Plugin < DiscoursePlugin

    def setup
      # add_setting(:enable_imgur, false)
      # add_setting(:imgur_client_id, '')
      # add_setting(:imgur_endpoint, "https://api.imgur.com/3/image.json")

      # TODO: Mix the following logic in Upload#store_file
      # return Imgur.store_file(file, image_info, upload_id) if SiteSetting.enable_imgur?
    end

  end

end
