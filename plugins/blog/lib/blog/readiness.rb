# frozen_string_literal: true

module ::Blog
  # The site settings that must be in place before articles can be published or reviewed.
  class Readiness
    Problem =
      Data.define(:key, :settings) do
        def message
          I18n.t("blog.errors.#{key}")
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
          SiteSetting.blog_contributor_groups_map + SiteSetting.blog_editor_groups_map +
          SiteSetting.blog_publisher_groups_map
      ).uniq
    end
    private_class_method :editorial_group_ids

    # Ordered so the first problem is the one to fix first.
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
      return if category && !category.read_restricted?
      Problem.new(key: :category, settings: %i[blog_category])
    end

    def drafts_category_problem
      return if self.class.valid_drafts_category?(drafts)
      Problem.new(key: :drafts_category, settings: %i[blog_drafts_category])
    end

    def category
      return @category if defined?(@category)
      @category = Category.find_by(id: SiteSetting.blog_category)
    end

    def drafts
      return @drafts if defined?(@drafts)
      @drafts = Category.find_by(id: SiteSetting.blog_drafts_category)
    end
  end
end
