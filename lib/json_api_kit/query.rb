# frozen_string_literal: true

module JsonApiKit
  # A listing being read: the sequence from the rows a resource exposes to the records of one page,
  # in the one place that knows it. What a caller asks for is JSON:API in concept and ours in shape,
  # a controller having already checked it against the spec, so nothing here parses a request.
  #
  # Nothing runs until records are asked for, which is what lets a query be handed on: a sideload
  # and a nested route are this same object scoped to another listing's rows.
  class Query
    # Until a resource declares its own limits.
    PAGE_SIZE = 25

    def initialize(resource, params = {}, guardian:, scoped_to: nil)
      @resource = resource
      @params = params
      @guardian = guardian
      @scoped_to = scoped_to
    end

    def records = page.records

    private

    attr_reader :resource, :params, :guardian, :scoped_to

    def page = @page ||= Pagination::Paginator.for(scope, order:, size: PAGE_SIZE)

    # The rows this query reads: the ones the resource offers, narrowed by the filtering asked
    # for, and kept to those of the listing it is being read as part of.
    def scope
      return filtered unless scoped_to
      filtered.merge(scoped_to)
    end

    def filtered = resource.filters.apply(available_rows, params[:filter])

    def available_rows = resource.scope_for(guardian)

    def order = resource.order(params[:sort])
  end
end
