# frozen_string_literal: true

module PrettyText
  module Helpers
    extend self

    TAG_HASHTAG_POSTFIX = "::tag"

    # functions here are available to v8
    def t(key, opts)
      key = "js." + key
      return I18n.t(key) if opts.blank?
      str = I18n.t(key, Hash[opts.entries].symbolize_keys).dup
      opts.each { |k, v| str.gsub!("{{#{k}}}", v.to_s) }
      str
    end

    def avatar_template(username)
      return "" unless username
      user = User.find_by(username_lower: username.downcase)
      return "" if user.blank?

      # TODO: Add support for ES6 and call `avatar-template` directly
      UrlHelper.schemaless(UrlHelper.absolute(user.avatar_template))
    end

    def lookup_primary_user_group(username)
      return "" unless username
      user = User.find_by(username_lower: username.downcase)
      return "" if user.blank?

      user.primary_group.try(:name) || ""
    end

    # Overwrite this in a plugin to change how markdown can format
    # usernames on the server side
    def format_username(username)
      username
    end

    def lookup_upload_urls(urls)
      map = {}
      result = {}

      urls.each do |url|
        sha1 = Upload.sha1_from_short_url(url)
        if url.split(".")[1].nil? # video sha1 without extension for thumbnail
          thumbnail = Upload.where("original_filename LIKE ?", "#{sha1}.%").last if sha1
          # Fallback for old posts that don't contain data-video-base62-sha1
          thumbnail = Upload.where("original_filename LIKE ?", "#{url}.%").last if thumbnail.nil? &&
            sha1.nil?
          sha1 = thumbnail.sha1 if thumbnail
        end
        map[url] = sha1 if sha1
      end

      if map.length > 0
        reverse_map = {}

        map.each do |key, value|
          reverse_map[value] ||= []
          reverse_map[value] << key
        end

        Upload
          .where(sha1: map.values)
          .pluck(:sha1, :url, :extension, :secure)
          .each do |row|
            sha1, url, extension, secure = row

            if short_urls = reverse_map[sha1]
              secure_uploads = SiteSetting.secure_uploads? && secure

              short_urls.each do |short_url|
                result[short_url] = {
                  url:
                    (
                      if secure_uploads
                        Upload.secure_uploads_url_from_upload_url(url)
                      else
                        Discourse.store.cdn_url(url)
                      end
                    ),
                  short_path: Upload.short_path(sha1: sha1, extension: extension),
                  base62_sha1: Upload.base62_sha1(sha1),
                }
              end
            end
          end
      end

      result
    end

    def get_topic_info(topic_id)
      return unless topic_id.is_a?(Integer)
      # TODO this only handles public topics, secured one do not get this
      topic = Topic.find_by(id: topic_id)
      if topic && Guardian.new.can_see?(topic)
        { title: Rack::Utils.escape_html(topic.title), href: topic.url }
      elsif topic
        { title: I18n.t("on_another_topic"), href: topic.slugless_url }
      end
    end

    def hashtag_lookup(slug, cooking_user_id, types_in_priority_order)
      # Missing or invalid user IDs cook with anonymous permissions. Callers that
      # need wider access must pass an explicit trusted user_id.
      cooking_user = User.find_by(id: cooking_user_id)

      types_in_priority_order =
        types_in_priority_order.select do |type|
          HashtagAutocompleteService.data_source_types.include?(type)
        end

      result =
        HashtagAutocompleteService.new(Guardian.new(cooking_user)).lookup(
          [slug],
          types_in_priority_order,
        )

      found_hashtag = nil
      types_in_priority_order.each do |type|
        if result[type.to_sym].any?
          found_hashtag = result[type.to_sym].first.to_h
          break
        end
      end
      found_hashtag
    end

    def get_current_user(user_id)
      return unless user_id.is_a?(Integer)
      { staff: User.where(id: user_id).where("moderator OR admin").exists? }
    end
  end
end
