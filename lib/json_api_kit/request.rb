# frozen_string_literal: true

module JsonApiKit
  class Request
    attr_reader :guardian

    def initialize(params = {}, guardian:)
      @params = ActiveSupport::HashWithIndifferentAccess.new(params)
      @page_params = @params[:page].to_h.symbolize_keys
      @guardian = guardian
    end

    def ordering = @ordering ||= params[:sort].to_h

    def filtering = @filtering ||= params[:filter].to_h

    def fields = @fields ||= params[:fields].to_h

    def including = @including ||= Paths.new(params[:include])

    def for_sideload(paths) = { fields:, include: paths }

    def page = @page ||= Page::Requested.for(anchoring:, **paging)

    def anchoring = @anchoring ||= Anchoring.for(page_params[:anchor])

    def item_cursors? = page_params[:item_cursors].present?

    private

    attr_reader :params, :page_params

    def paging
      page_params
        .except(:item_cursors, :anchor)
        .merge(after: cursor(:after), before: cursor(:before))
        .compact
    end

    def cursor(name)
      return unless page_params[name]
      Pagination::Cursor.parse(page_params[name])
    end
  end
end
