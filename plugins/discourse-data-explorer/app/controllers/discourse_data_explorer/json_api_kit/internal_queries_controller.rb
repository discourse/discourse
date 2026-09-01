# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # An endpoint shaped for our own client rather than for integrators — the same
    # resource, published differently (docs/resource-design.md §9). Declaring it
    # `internal!` drops it from the generated documentation and from the versioning
    # contract; everything else the framework provides is unchanged.
    #
    # It exists in the spike to prove that publication is a per-endpoint decision,
    # not a property of a resource.
    class InternalQueriesController < BaseController
      resource QueryResource
      internal!
    end
  end
end
