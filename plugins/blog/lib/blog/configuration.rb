# frozen_string_literal: true

module ::Blog
  module Configuration
    ASSET_PREFIXES = %w[
      plugins
      uploads
      assets
      stylesheets
      javascripts
      font
      images
      extra-locales
      svg-sprite
    ].freeze

    def self.asset_path?(path)
      ASSET_PREFIXES.include?(path.split("/")[1])
    end

    def self.origin
      SiteSetting.blog_url
    end

    def self.configured_origin?
      origin.present? && URI(origin).host != Discourse.current_hostname
    end

    def self.blog_host?(request)
      SiteSetting.blog_enabled && configured_origin? && request.host == URI(origin).host
    end

    def self.public_enabled?
      SiteSetting.blog_enabled && configured_origin? && !SiteSetting.login_required &&
        !SiteSetting.secure_uploads && !SiteSetting.prevent_anons_from_downloading_files
    end

    def self.error
      if origin.blank? || URI(origin).host == Discourse.current_hostname
        return I18n.t("blog.errors.origin")
      end
      if SiteSetting.login_required || SiteSetting.secure_uploads
        return I18n.t("blog.errors.private_site")
      end
      if SiteSetting.prevent_anons_from_downloading_files
        return I18n.t("blog.errors.anonymous_uploads")
      end
      category = Category.find_by(id: SiteSetting.blog_category)
      drafts = Category.find_by(id: SiteSetting.blog_drafts_category)
      return I18n.t("blog.errors.category") if !category || category.read_restricted?
      if !drafts || !drafts.read_restricted? || category.id == drafts.id ||
           drafts.id == SiteSetting.shared_drafts_category.to_i ||
           drafts.category_groups.where.not(group_id: editorial_group_ids).exists?
        return I18n.t("blog.errors.drafts_category")
      end
      nil
    end

    def self.ensure_ready!
      raise Discourse::InvalidParameters.new(error) if error
    end

    def self.publisher?(user)
      role_user?(user) &&
        (user.admin? || in_role_groups?(user, SiteSetting.blog_publisher_groups_map))
    end

    def self.editor?(user)
      publisher?(user) ||
        (role_user?(user) && in_role_groups?(user, SiteSetting.blog_editor_groups_map))
    end

    def self.contributor?(user)
      editor?(user) ||
        (role_user?(user) && in_role_groups?(user, SiteSetting.blog_contributor_groups_map))
    end

    def self.in_role_groups?(user, groups)
      return true if groups.include?(Group::AUTO_GROUPS[:staff]) && user.staff?
      return true if groups.include?(Group::AUTO_GROUPS[:admins]) && user.admin?
      return true if groups.include?(Group::AUTO_GROUPS[:moderators]) && user.moderator?
      user.in_any_groups?(
        groups -
          [
            Group::AUTO_GROUPS[:staff],
            Group::AUTO_GROUPS[:admins],
            Group::AUTO_GROUPS[:moderators],
          ],
      )
    end
    private_class_method :in_role_groups?

    def self.editorial_group_ids
      (
        [Group::AUTO_GROUPS[:admins], Group::AUTO_GROUPS[:moderators], Group::AUTO_GROUPS[:staff]] +
          SiteSetting.blog_contributor_groups_map + SiteSetting.blog_editor_groups_map +
          SiteSetting.blog_publisher_groups_map
      ).uniq
    end

    def self.role_user?(user)
      SiteSetting.blog_enabled && user&.active? && !user.suspended? && !user.silenced?
    end
    private_class_method :role_user?

    def self.ensure_publisher!(user, topic)
      raise Discourse::InvalidAccess unless publisher?(user)
      ensure_editor!(user, topic)
    end

    def self.ensure_editor!(user, topic)
      raise Discourse::InvalidAccess unless contributor?(user)
      user.guardian.ensure_can_see!(topic)
      raise Discourse::InvalidAccess unless editor?(user) || topic.user_id == user.id
      categories = [SiteSetting.blog_category.to_i, SiteSetting.blog_drafts_category.to_i]
      if topic.private_message? || topic.shared_draft? || !categories.include?(topic.category_id) ||
           topic.category&.topic_id == topic.id || topic.deleted_at || !topic.visible
        raise Discourse::InvalidAccess
      end
    end
  end
end
