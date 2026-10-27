# frozen_string_literal: true

module JsonApiKit
  class Request
    LIST = ","
    SORT_DIRECTIONS = { "-" => :desc, "" => :asc }.freeze

    attr_reader :guardian, :edition

    def initialize(params = {}, guardian:, edition:)
      @params = ActiveSupport::HashWithIndifferentAccess.new(params)
      @page_params = @params[:page].to_h.symbolize_keys
      @guardian = guardian
      @edition = edition
    end

    def ordering = params.fetch(:sort)

    def filtering = @filtering ||= params[:filter].to_h

    def fields = @fields ||= params[:fields].to_h

    def including = @including ||= Paths.new(params[:include])

    def for_sideload(paths, through:)
      { fields:, include: paths }.merge(
        params.fetch(:forwarded_filters, {}).fetch(through.to_s, {}).symbolize_keys,
      )
    end

    def page = page_params

    def anchoring = @anchoring ||= Anchoring.for(page_params[:anchor])

    def item_cursors? = page_params[:item_cursors].present?

    private

    attr_reader :params, :page_params
  end
end
