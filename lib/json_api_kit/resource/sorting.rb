# frozen_string_literal: true

module JsonApiKit
  class Resource
    # How a resource lets its listings be ordered: the sorts it offers a caller, what it reads when
    # none is named, and the key that leaves no two rows sharing a place. It records them and hands
    # them to `Declarations::Sorts`, which turns a request into the order a page is read along.
    module Sorting
      extend ActiveSupport::Concern

      # Declarations are copied on write, never appended to in place: a `class_attribute` default is
      # one object shared by every resource that has not written its own, so `<<` would add a sort
      # to all of them at once. Frozen, so that mistake raises rather than leaking — the helper
      # takes a value, not something it calls per class.
      included do
        class_attribute :declared_unique_by, instance_accessor: false, instance_predicate: false
        class_attribute :declared_sorts,
                        default: [].freeze,
                        instance_accessor: false,
                        instance_predicate: false
        class_attribute :declared_default_sort,
                        default: {}.freeze,
                        instance_accessor: false,
                        instance_predicate: false
        private_class_method :declared_sorts,
                             :declared_sorts=,
                             :declared_default_sort,
                             :declared_default_sort=,
                             :declared_unique_by,
                             :declared_unique_by=
      end

      class_methods do
        # Declares a way this resource's listings may be ordered — `sort :name`,
        # `sort :ran_at, column: :last_run_at`, `sort "user.username", sql: …, joins: …`.
        def sort(name, **options)
          self.declared_sorts = declared_sorts + [Declarations::Sort.new(name, **options)]
        end

        # Declares what a listing is ordered by when a request names nothing.
        def default_sort(ordering)
          self.declared_default_sort = ordering
        end

        # Declares the columns no two rows share, which every order this resource reads ends with:
        # a page cannot be read reliably from an order two rows can sit in the same place of. The
        # model's own key unless a resource knows better.
        def unique_by(*columns)
          self.declared_unique_by = columns
        end

        # Everything this resource says about ordering its listings, as one collaborator. Built
        # each time rather than held: a plugin declares sorts on a resource long after its class
        # body ran, and a collection kept from before would not have them.
        def sorts
          Declarations::Sorts.new(
            declared_sorts,
            model:,
            default: declared_default_sort,
            unique_by: declared_unique_by,
          )
        end

        # The order a listing is read in, for the ordering asked for — the sorts to read by, each
        # with its direction: the bands the listing falls into, and the comparison inside each of
        # them (see Pagination::Order).
        def order(ordering = {}) = Pagination::Order.for(sorts.keyset(ordering))
      end
    end
  end
end
