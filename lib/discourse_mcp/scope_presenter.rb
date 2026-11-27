# frozen_string_literal: true

module DiscourseMcp
  # Describes OAuth scopes in plain words, split into what an app can do as the
  # person and what it can do to run the site.
  module ScopePresenter
    Item = Data.define(:scope, :label)
    Section = Data.define(:name, :items)

    # A scope that any administration or moderation tool needs counts as running
    # the site, so new tools land in the right section without updating a list.
    MANAGE_RISKS = %i[administration moderation].freeze

    # Core areas in display order. Other areas, like plugins', follow alphabetically.
    AREA_ORDER = %w[
      mcp:profile
      mcp:content
      mcp:private-messages
      mcp:drafts
      mcp:repository
      mcp:site-settings
      mcp:themes
      mcp:categories
      mcp:tag-groups
      mcp:groups
      mcp:users
      mcp:moderation
      mcp:reports
      mcp:webhooks
    ].freeze

    def self.sections(scopes)
      manage_scopes = scopes_needed_by(MANAGE_RISKS)
      manage, member = items(scopes).partition { |item| manage_scopes.include?(item.scope) }

      [
        Section.new(name: "member", items: member),
        Section.new(name: "manage", items: manage),
      ].select { |section| section.items.present? }
    end

    def self.items(scopes)
      scopes
        .uniq
        .sort_by { |scope| sort_key(scope) }
        .map { |scope| Item.new(scope:, label: label(scope)) }
    end

    # Scopes without a translation, like those of plugins that don't describe them,
    # have no label, so the page shows the scope itself.
    def self.label(scope)
      I18n.t("mcp.oauth.scopes.#{scope.downcase.gsub(/[^a-z0-9]+/, "_")}", default: "").presence
    end

    def self.scopes_needed_by(risks)
      DiscourseMcp
        .registry
        .all
        .select { |primitive| risks.include?(primitive.risk) }
        .flat_map(&:required_scopes)
        .to_set
    end
    private_class_method :scopes_needed_by

    def self.sort_key(scope)
      area, _, access = scope.rpartition(":")
      [AREA_ORDER.index(area) || AREA_ORDER.size, area, access == "read" ? 0 : 1, scope]
    end
    private_class_method :sort_key
  end
end
