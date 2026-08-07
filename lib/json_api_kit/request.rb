# frozen_string_literal: true

module JsonApiKit
  # What a caller brought: what they asked for, and who they are.
  #
  # These are JSON:API concepts in the shape our objects read them in — a controller has already
  # checked `sort=-created_at` against the spec and handed over `sort: { created_at: :desc }` — so
  # nothing below here parses a request. What this adds is that the shape is *named*: every
  # parameter the kit reads has a reader, and anything else is refused, since a request the kit
  # silently ignores is one a caller believes was honoured.
  class Request
    Unsupported = Class.new(StandardError)

    READ = %i[sort filter page].freeze
    PAGING = %i[size after before].freeze

    attr_reader :guardian

    def initialize(params = {}, guardian:)
      refuse_unknown(params, READ)
      refuse_unknown(params[:page], PAGING)

      @params = params
      @guardian = guardian
    end

    # The sorts to read by, each with its direction; nothing, where the resource's own order is
    # what the caller wants.
    def ordering = params[:sort] || {}

    # The filters to narrow by, each with its value.
    def filtering = params[:filter] || {}

    # How large a page to read, for the resource to allow or refuse.
    def page_size = params.dig(:page, :size)

    # Where to read the listing on from, and back from. A cursor is the one parameter no
    # controller can check, its content being ours rather than the spec's, so it is read here —
    # and a cursor that is not one is refused like any other request the kit cannot honour.
    def after = cursor(params.dig(:page, :after))

    def before = cursor(params.dig(:page, :before))

    private

    attr_reader :params

    def cursor(raw) = raw && Pagination::Cursor.parse(raw)

    def refuse_unknown(asked, read)
      unknown = asked.to_h.keys.map(&:to_sym) - read
      return if unknown.empty?
      raise Unsupported, "nothing is read from #{unknown.join(", ")}"
    end
  end
end
