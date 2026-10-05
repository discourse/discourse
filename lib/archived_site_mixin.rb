# frozen_string_literal: true

# Site archival is a policy state (site_archived setting), orthogonal to the
# operational readonly stack. When archived, non-GET requests are blocked with
# Discourse::SiteArchived unless the action is explicitly declared with
# `allow_when_archived`. Reads are always permitted.
#
# Controllers that should be fully exempt (e.g. AdminController) can
# `skip_before_action :block_if_archived`.
module ArchivedSiteMixin
  module ClassMethods
    def actions_allowed_when_archived
      @actions_allowed_when_archived ||= []
    end

    def allow_when_archived(*actions)
      actions_allowed_when_archived.concat(actions.map(&:to_sym))
    end

    def allowed_when_archived?(action)
      actions_allowed_when_archived.include?(action.to_sym)
    end
  end

  def block_if_archived
    return if request.get? || request.head?
    return unless SiteSetting.site_archived
    return if self.class.allowed_when_archived?(action_name)
    raise Discourse::SiteArchived
  end

  def self.included(base)
    base.extend(ClassMethods)
  end
end
