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
      opts.each { |k, v| str.gsub!("{{#{k.to_s}}}", v.to_s) }
      str
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

        Upload
          .where(sha1: map.values)
          .pluck(:sha1, :url, :extension, :original_filename, :secure)
          .each do |row|
            sha1, url, extension, original_filename, secure = row

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
        { title: I18n.t("on_another_topic"), href: Discourse.base_url + topic.slugless_url }
      end
    end

    # TODO (martin) Remove this when everything is using hashtag_lookup
    # after enable_experimental_hashtag_autocomplete is default.
    def category_tag_hashtag_lookup(text)
      is_tag = text =~ /#{TAG_HASHTAG_POSTFIX}\z/

      if !is_tag && category = Category.query_from_hashtag_slug(text)
        [category.url, text]
      elsif (!is_tag && tag = Tag.find_by(name: text)) ||
            (is_tag && tag = Tag.find_by(name: text.gsub!(TAG_HASHTAG_POSTFIX, "")))
        [tag.url, text]
      else
        nil
      end
    end

    def hashtag_lookup(slug, cooking_user_id, types_in_priority_order)
      # NOTE: This is _somewhat_ expected since we need to be able to cook posts
      # etc. without a user sometimes, but it is still an edge case.
      #
      # The Discourse.system_user is usually an admin with access to _all_
      # categories, however if the suppress_secured_categories_from_admin
      # site setting is activated then this user will not be able to access
      # secure categories, so hashtags that are secure will not render.
      if cooking_user_id.blank?
        cooking_user = Discourse.system_user
      else
        cooking_user = User.find(cooking_user_id)
      end

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
