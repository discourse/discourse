# frozen_string_literal: true

module JsonApiKit
  module Name
    # `collection` names the resource's collection that declares the filter, or nil for the
    # resource's own listing, so the same filter name can mean different things in each.
    Filter =
      Data.define(:value, :type, :collection) do
        include Name::ResourceScope

        def initialize(value:, type:, collection: nil) = super
      end
  end
end
