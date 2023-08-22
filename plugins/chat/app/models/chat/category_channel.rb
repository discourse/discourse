# frozen_string_literal: true

module Chat
  class CategoryChannel < Channel
    alias_attribute :category, :chatable

    delegate :read_restricted?, to: :category
    delegate :url, to: :chatable, prefix: true

    %i[category_channel? public_channel? chatable_has_custom_fields?].each do |name|
      define_method(name) { true }
    end

    def allowed_group_ids
      return if !read_restricted?

      staff_groups = Group::AUTO_GROUPS.slice(:staff, :moderators, :admins).values
      category.secure_group_ids.to_a.concat(staff_groups)
    end

    def title(_ = nil)
      name.presence || category.name
    end

    def generate_auto_slug
      return if self.slug.present?
      self.slug = Slug.for(self.title.strip, "")
      self.slug = "" if duplicate_slug?
    end

    def ensure_slug_ok
      if self.slug.present?
        # if we don't unescape it first we strip the % from the encoded version
        slug = SiteSetting.slug_generation_method == "encoded" ? CGI.unescape(self.slug) : self.slug
        self.slug = Slug.for(slug, "", method: :encoded)

        if self.slug.blank?
          errors.add(:slug, :invalid)
        elsif SiteSetting.slug_generation_method == "ascii" && !CGI.unescape(self.slug).ascii_only?
          errors.add(:slug, I18n.t("chat.category_channel.errors.slug_contains_non_ascii_chars"))
        elsif duplicate_slug?
          errors.add(:slug, I18n.t("chat.category_channel.errors.is_already_in_use"))
        end
      end
    end
  end
end
