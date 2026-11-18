# frozen_string_literal: true

module ::Blog
  # The site settings that must be in place before articles can be published or reviewed.
  class Readiness
    Problem =
      Data.define(:key, :settings) do
        def message
          I18n.t("blog.errors.#{key}", name: ManagedCategories.public_category_name)
        end
      end

    def self.ensure!
      new.ensure!
    end

    def self.valid_drafts_category?(drafts)
      return false if !drafts&.read_restricted?
      return false if drafts.id == SiteSetting.blog_category.to_i
      return false if drafts.id == SiteSetting.shared_drafts_category.to_i
      !drafts.category_groups.where.not(group_id: editorial_group_ids).exists?
    end

    def self.editorial_group_ids
      (
        Group::AUTO_GROUPS.values_at(:admins, :moderators, :staff) +
          ManagedCategories.editorial_group_ids
      ).uniq
    end
    private_class_method :editorial_group_ids

    # Ordered so the first problem is the one to fix first. Missing categories are
    # not problems: the blog creates them when it first needs them.
    def problems
      @problems ||= [
        private_site_problem,
        anonymous_uploads_problem,
        category_problem,
        drafts_category_problem,
      ].compact
    end

    def ready?
      problems.empty?
    end

    def error
      problems.first&.message
    end

    def ensure!
      raise Discourse::InvalidParameters.new(error) if !ready?
    end

    private

    def private_site_problem
      settings = %i[login_required secure_uploads].select { |name| SiteSetting.get(name) }
      Problem.new(key: :private_site, settings:) if settings.present?
    end

    def anonymous_uploads_problem
      return if !SiteSetting.prevent_anons_from_downloading_files
      Problem.new(key: :anonymous_uploads, settings: %i[prevent_anons_from_downloading_files])
    end

    def category_problem
      category = ManagedCategories.public_category
      return Problem.new(key: :category, settings: %i[blog_category]) if category&.read_restricted?
      return if category || !ManagedCategories.public_category_name_taken?
      Problem.new(key: :category_name_taken, settings: %i[blog_category])
    end

    # The setting is managed by the blog, so the fix is in the category itself.
    def drafts_category_problem
      drafts = ManagedCategories.drafts_category
      return if drafts.nil? || drafts.read_restricted?
      Problem.new(key: :drafts_category_public, settings: [])
    end
  end
end
