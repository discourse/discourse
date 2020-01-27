# frozen_string_literal: true

module PrettyText
  module Helpers
    extend self

    # functions here are available to v8
    def t(key, opts)
      key = "js." + key
      unless opts
        I18n.t(key)
      else
        str = I18n.t(key, Hash[opts.entries].symbolize_keys).dup
        opts.each { |k, v| str.gsub!("{{#{k.to_s}}}", v.to_s) }
        str
      end
    end

    def avatar_template(username)
      return "" unless username
      user = User.find_by(username_lower: username.downcase)
      return "" unless user.present?

      # TODO: Add support for ES6 and call `avatar-template` directly
      UrlHelper.schemaless(UrlHelper.absolute(user.avatar_template))
    end

    def lookup_primary_user_group(username)
      return "" unless username
      user = User.find_by(username_lower: username.downcase)
      return "" unless user.present?

      user.primary_group.try(:name) || ""
    end

    # Overwrite this in a plugin to change how markdown can format
    # usernames on the server side
    def format_username(username)
      username
    end

    def category_hashtag_lookup(category_slug)
      if category = Category.query_from_hashtag_slug(category_slug)
        [category.url_with_id, category_slug]
      else
        nil
      end
    end

    def lookup_upload_urls(urls)
      map = {}
      result = {}

      urls.each do |url|
        sha1 = Upload.sha1_from_short_url(url)
        map[url] = sha1 if sha1
      end

      if map.length > 0
        reverse_map = {}

        map.each do |key, value|
          reverse_map[value] ||= []
          reverse_map[value] << key
        end

        Upload.where(sha1: map.values).pluck(:sha1, :url, :extension, :original_filename, :secure).each do |row|
          sha1, url, extension, original_filename, secure = row

          if short_urls = reverse_map[sha1]
            secure_media = FileHelper.is_supported_media?(original_filename) && SiteSetting.secure_media? && secure

            short_urls.each do |short_url|
              result[short_url] = {
                url: secure_media ? Upload.secure_media_url_from_upload_url(url) : Discourse.store.cdn_url(url),
                short_path: Upload.short_path(sha1: sha1, extension: extension),
                base62_sha1: Upload.base62_sha1(sha1)
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
        {
          title: Rack::Utils.escape_html(topic.title),
          href: topic.url
        }
      elsif topic
        {
          title: I18n.t("on_another_topic"),
          href: Discourse.base_url + topic.slugless_url
        }
      end
    end

    def category_tag_hashtag_lookup(text)
      tag_postfix = '::tag'
      is_tag = text =~ /#{tag_postfix}$/

      if !is_tag && category = Category.query_from_hashtag_slug(text)
        [category.url_with_id, text]
      elsif (!is_tag && tag = Tag.find_by(name: text)) ||
            (is_tag && tag = Tag.find_by(name: text.gsub!("#{tag_postfix}", '')))
        ["#{Discourse.base_url}/tag/#{tag.name}", text]
      else
        nil
      end
    end

    def get_current_user(user_id)
      return unless user_id.is_a?(Integer)
      { staff: User.where(id: user_id).where("moderator OR admin").exists? }
    end
  end
end
