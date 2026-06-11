# frozen_string_literal: true

module DiscourseDataExplorer
  # Base resource for the JSON:API modernization spike (Graphiti).
  # See docs/api-modernization-exploration.md.
  class ApplicationResource < Graphiti::Resource
    self.abstract_class = true
    self.adapter = Graphiti::Adapters::ActiveRecord
    self.endpoint_namespace = "/data-explorer/api/v1"

    # Spike: keep the surface minimal for now — no auto-generated relationship
    # links and no endpoint inference/validation until we wire routing properly.
    self.autolink = false
    self.validate_endpoints = false

    # Public-API hardening: Graphiti makes every attribute filterable/sortable/
    # writable by default — flip to opt-in so the exposed query surface and the
    # accepted write payload are deliberate.
    # NOTE: sideloads and #find work by filtering on :id, so resources that are
    # sideloaded or fetched by id must explicitly re-enable `filter :id`.
    self.attributes_filterable_by_default = false
    self.attributes_sortable_by_default = false
    self.attributes_writable_by_default = false

    # `context` is the controller (or any stand-in passed to
    # Graphiti.with_context) — the Guardian seam for all resources.
    def guardian
      context.guardian
    end

    def current_user
      guardian.user
    end

    # Graphiti's AR adapter paginates via Kaminari (.page/.per), which Discourse
    # doesn't ship. Supply a custom proc so we depend on neither Kaminari nor an
    # adapter override. NOTE: this is plain offset/limit — Graphiti's built-in
    # "cursor" pagination is also offset-based, so real keyset/cursor pagination
    # (planned via the `pagy` gem) will replace this block in a later step.
    paginate do |scope, current_page, per_page, _ctx, offset|
      per_page = (per_page || 20).to_i
      current_page = (current_page || 1).to_i
      scope.limit(per_page).offset((current_page - 1) * per_page + offset.to_i)
    end
  end
end
