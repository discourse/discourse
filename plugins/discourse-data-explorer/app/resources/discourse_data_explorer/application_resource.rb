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
    # doesn't ship, so we supply our own proc with two modes:
    #
    # - default: plain offset/limit (page[number]/page[size]).
    # - keyset (pagy): engaged by page[cursor]. NOT page[after] — Graphiti
    #   eagerly decodes page[after]/[before] as a Base64 JSON *hash* of its own
    #   offset-cursors and 500s on a foreign (pagy) cutoff. Cursor mode pins
    #   its own ordering (id desc): the default sort's last_run_at is nullable,
    #   and keyset pagination over nullable columns is a correctness trap. The
    #   next cutoff is handed back through the context (controller) and
    #   rendered in the document's meta.
    paginate do |scope, current_page, per_page, ctx, offset|
      per_page = (per_page || 20).to_i
      cursor = ctx.respond_to?(:params) ? ctx.params.dig(:page, :cursor) : nil

      if cursor.present?
        pagy = Pagy::Keyset.new(scope.reorder(id: :desc), page: cursor, limit: per_page)
        ctx.next_page_cursor = pagy.next if ctx.respond_to?(:next_page_cursor=)
        pagy.records
      else
        current_page = (current_page || 1).to_i
        scope.limit(per_page).offset((current_page - 1) * per_page + offset.to_i)
      end
    end
  end
end
