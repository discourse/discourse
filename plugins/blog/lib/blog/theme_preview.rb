# frozen_string_literal: true

module ::Blog
  # Signed, expiring capabilities that render a theme on the public blog without
  # activating it: a preset, a saved draft at a given revision, or an unsaved
  # working copy held briefly in Redis.
  class ThemePreview
    DRAFT_EXPIRY = 1.hour
    WORKING_COPY_EXPIRY = 15.minutes
    MAX_WORKING_COPIES = 3

    def self.url(token, path: "/", blog: Instance.default_blog)
      "#{Configuration.base_url(blog)}#{path}?#{{ blog_theme_preview: token }.to_query}"
    end

    def self.token_for(theme, blog:)
      verifier.generate(
        { "id" => theme["id"], "revision" => theme["revision"], "blog_id" => blog.id },
        expires_in: DRAFT_EXPIRY,
      )
    end

    # A preview link shows a blog that is not published yet, so it only does that
    # for the blog it was made for.
    def self.for_blog?(token, blog)
      return false if token.blank?
      data = verifier.verified(token)
      data.is_a?(Hash) && data["blog_id"] == blog.id
    end

    # Only the newest working copies per editor stay previewable.
    def self.store_working_copy(values, user:, blog:)
      key = SecureRandom.hex(32)
      DistributedMutex.synchronize("blog-theme-preview-#{user.id}") do
        index = "blog-theme-preview-index:#{user.id}"
        keys = JSON.parse(Discourse.redis.get(index) || "[]")
        keys << key
        if keys.length > MAX_WORKING_COPIES
          keys
            .shift(keys.length - MAX_WORKING_COPIES)
            .each { |old_key| Discourse.redis.del(working_copy_key(old_key)) }
        end
        Discourse.redis.setex(working_copy_key(key), WORKING_COPY_EXPIRY.to_i, values.to_json)
        Discourse.redis.setex(index, WORKING_COPY_EXPIRY.to_i, keys.to_json)
      end
      verifier.generate({ "working" => key, "blog_id" => blog.id }, expires_in: WORKING_COPY_EXPIRY)
    end

    def self.theme_for(token)
      data = verifier.verified(token)
      raise Discourse::NotFound unless data.is_a?(Hash)
      if data["working"]
        stored = Discourse.redis.get(working_copy_key(data["working"]))
        raise Discourse::NotFound unless stored
        return JSON.parse(stored)
      end
      theme = ThemePresets.find(data["id"]) || BlogTheme.find(data["id"])
      raise Discourse::NotFound unless theme["revision"] == data["revision"]
      theme
    end

    def self.working_copy_key(key)
      "blog-theme-preview:#{key}"
    end
    private_class_method :working_copy_key

    def self.verifier
      Rails.application.message_verifier(
        "discourse-blog-theme-#{RailsMultisite::ConnectionManagement.current_db}",
      )
    end
    private_class_method :verifier
  end
end
