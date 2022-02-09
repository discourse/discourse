# frozen_string_literal: true

module ImportScripts::PhpBB3
  class SmileyProcessor
    # @param uploader [ImportScripts::Uploader]
    # @param database [ImportScripts::PhpBB3::Database_3_0 | ImportScripts::PhpBB3::Database_3_1]
    # @param settings [ImportScripts::PhpBB3::Settings]
    # @param phpbb_config [Hash]
    def initialize(uploader, database, settings, phpbb_config)
      @uploader = uploader
      @database = database
      @smilies_path = File.join(settings.base_dir, phpbb_config[:smilies_path])

      @smiley_map = {}
      add_default_smilies
      add_configured_smilies(settings.emojis)
    end

    def replace_smilies(text)
      # :) is encoded as <!-- s:) --><img src="{SMILIES_PATH}/icon_e_smile.gif" alt=":)" title="Smile" /><!-- s:) -->
      text.gsub!(/<!-- s(\S+) --><img src="\{SMILIES_PATH\}\/.+?" alt=".*?" title=".*?" \/><!-- s?\S+ -->/) do
        emoji($1)
      end
    end

    def emoji(smiley_code)
      @smiley_map.fetch(smiley_code) do
        smiley = @database.get_smiley(smiley_code)
        emoji = upload_smiley(smiley_code, smiley[:smiley_url], smiley_code, smiley[:emotion]) if smiley
        emoji || smiley_as_text(smiley_code)
      end
    end

    protected

    def add_default_smilies
      {
        [':D', ':-D', ':grin:'] => ':smiley:',
        [':)', ':-)', ':smile:'] => ':slight_smile:',
        [';)', ';-)', ':wink:'] => ':wink:',
        [':(', ':-(', ':sad:'] => ':frowning:',
        [':o', ':-o', ':eek:'] => ':astonished:',
        [':shock:'] => ':open_mouth:',
        [':?', ':-?', ':???:'] => ':confused:',
        ['8)', '8-)', ':cool:'] => ':sunglasses:',
        [':lol:'] => ':laughing:',
        [':x', ':-x', ':mad:'] => ':angry:',
        [':P', ':-P', ':razz:'] => ':stuck_out_tongue:',
        [':oops:'] => ':blush:',
        [':cry:'] => ':cry:',
        [':evil:'] => ':imp:',
        [':twisted:'] => ':smiling_imp:',
        [':roll:'] => ':unamused:',
        [':!:'] => ':exclamation:',
        [':?:'] => ':question:',
        [':idea:'] => ':bulb:',
        [':arrow:'] => ':arrow_right:',
        [':|', ':-|'] => ':neutral_face:',
        [':geek:'] => ':nerd:'
      }.each do |smilies, emoji|
        smilies.each { |smiley| @smiley_map[smiley] = emoji }
      end
    end

    def add_configured_smilies(emojis)
      emojis.each do |emoji, smilies|
        Array.wrap(smilies)
          .each { |smiley| @smiley_map[smiley] = ":#{emoji}:" }
      end
    end

    def upload_smiley(smiley, path, alt_text, title)
      path = File.join(@smilies_path, path)
      filename = File.basename(path)
      upload = @uploader.create_upload(Discourse::SYSTEM_USER_ID, path, filename)

      if upload.nil? || !upload.persisted?
        puts "Failed to upload #{path}"
        puts upload.errors.inspect if upload
        html = nil
      else
        html = embedded_image_html(upload, alt_text, title)
        @smiley_map[smiley] = html
      end

      html
    end

    def embedded_image_html(upload, alt_text, title)
      image_width = [upload.width, SiteSetting.max_image_width].compact.min
      image_height = [upload.height, SiteSetting.max_image_height].compact.min
      %Q[<img src="#{upload.url}" width="#{image_width}" height="#{image_height}" alt="#{alt_text}" title="#{title}"/>]
    end

    def smiley_as_text(smiley)
      @smiley_map[smiley] = smiley
    end
  end
end
