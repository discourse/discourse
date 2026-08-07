# frozen_string_literal: true

module JsonApiKit
  # A listing being read: the sequence from the rows a resource exposes to the records of one page,
  # in the one place that knows it. A resource says what may be asked of it, a request says what was
  # asked, and this is where the two meet.
  #
  # Nothing runs until records are asked for, which is what lets a query be handed on: a sideload
  # and a nested route are this same object scoped to another listing's rows.
  class Query
    def initialize(resource, request, scoped_to: nil)
      @resource = resource
      @request = request
      @scoped_to = scoped_to
    end

    def rows = page.rows

    def records = page.records

    # The pages either side of this one, as the cursors they are read from.
    def next = page.next&.to_s

    def previous = page.previous&.to_s

    private

    attr_reader :resource, :request, :scoped_to

    delegate :guardian, :after, :before, to: :request, private: true

    def page = @page ||= Pagination::Paginator.for(scope, order:, size:, after:, before:)

    # The rows this query reads: the ones the resource offers, narrowed by the filtering asked
    # for, and kept to those of the listing it is being read as part of.
    def scope
      return filtered unless scoped_to
      filtered.merge(scoped_to)
    end

    def filtered = resource.filters.apply(available_rows, request.filtering)

    def available_rows = resource.scope_for(guardian)

    def order = resource.order(request.ordering)

    def size = resource.page_limits.size(request.page_size)
  end
end
