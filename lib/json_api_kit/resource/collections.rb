# frozen_string_literal: true

module JsonApiKit
  class Resource
    # Further list endpoints over the same records. A named collection keeps the resource's type,
    # scope, fields, sorts and paging, but declares its own filters, and version changes address
    # those filters through `collection` inside `resource`, apart from the resource's own.
    module Collections
      extend ActiveSupport::Concern

      included do
        class_attribute :declared_collections,
                        default: {}.freeze,
                        instance_accessor: false,
                        instance_predicate: false
        private_class_method :declared_collections, :declared_collections=
      end

      class_methods do
        # Declares the collection when given a block, and returns it otherwise.
        def collection(name, &declarations)
          name = name.to_s
          return collection_class(name) unless declarations

          if collection_name
            raise ArgumentError, "#{self}: the collection #{name} is inside another"
          end
          if declared_collections.key?(name)
            raise ArgumentError, "#{self}: the collection #{name} is already declared"
          end
          self.declared_collections = declared_collections.merge(name => declarations).freeze
        end

        def collection_names = declared_collections.keys

        # The name of the collection this class lists, or nil for the resource's own listing.
        def collection_name = nil

        private

        # Built for each class that asks, so a resource inheriting the declaration lists the
        # collection under its own type.
        def collection_class(name)
          declarations =
            declared_collections.fetch(name) do
              raise KeyError, "#{self}: there is no collection named #{name}"
            end
          (@collection_classes ||= {})[name] ||= build_collection(name, declarations)
        end

        def build_collection(name, declarations)
          owner = self
          Class.new(self) do
            type owner.type
            model owner.model
            self.declared_filters = [].freeze
            self.declared_collections = {}.freeze
            self.declared_input_scope = nil
            define_singleton_method(:collection_name) { name }
            define_singleton_method(:to_s) { "#{owner}[#{name}]" }
            singleton_class.alias_method :inspect, :to_s
            class_eval(&declarations)
          end
        end
      end

      delegate :collection_name, to: :class
    end
  end
end
