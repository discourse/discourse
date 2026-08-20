# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # One breaking API change, bound to the version (date) that introduced it.
    # Declarative and immutable — it describes a change that happened in the past
    # and is never instantiated. See docs/versioning-design.md.
    #
    # Key-level facts are DECLARED (`renamed_attribute`), so the machinery derives
    # every surface from data: body transforms (generated, key-guarded), sparse
    # fieldsets and error pointers (pure lookups — no value code ever runs outside
    # a real document). Value reshaping rides the declaration as pure value→value
    # converters, or hand-written `up`/`down` blocks for anything else. Rule: a
    # change that alters key names must declare them — block-only changes get no
    # fieldset/pointer mapping.
    #
    #   class ChangeThingsAddressToList < JsonApiKit::VersionChange
    #     version "2026-06-15"
    #     description "The `address` attribute of things is replaced by `addresses`."
    #
    #     resource :things do
    #       renamed_attribute from: :address,
    #                         to: :addresses,
    #                         up: ->(address) { [address] },
    #                         down: ->(addresses) { addresses.first }
    #     end
    #   end
    class VersionChange
      # Collects one scope's declared renames and hand-written blocks, and composes
      # them into one transform per direction. Blocks always operate on the
      # change's LATEST vocabulary: renames run first on up, last on down.
      class ResourceChanges
        def initialize
          @renames = []
          @sort_renames = {}
          @filter_renames = {}
          @blocks = { up: [], down: [] }
        end

        # `old_type:` declares the pre-rename wire type for shape-changing
        # renames (a converter that changes shape implies a type change) — the
        # versioned docs generator applies it to schemas so old-version schemas
        # and down-converted examples agree.
        def renamed_attribute(from:, to:, up: nil, down: nil, old_type: nil)
          @renames << { from: from.to_sym, to: to.to_sym, up:, down:, old_type: }
        end

        # Virtual sort/filter keys are their own contract surface: attribute renames
        # never touch them, so renaming one takes its own declaration.
        def renamed_sort(from:, to:) = @sort_renames[from.to_sym] = to.to_sym
        def renamed_filter(from:, to:) = @filter_renames[from.to_sym] = to.to_sym

        def up(&block) = @blocks[:up] << block
        def down(&block) = @blocks[:down] << block

        def field_renames = @renames.to_h { [it[:from], it[:to]] }
        def attribute_renames = @renames

        attr_reader :sort_renames, :filter_renames

        def transform(direction)
          @transforms ||= {}
          @transforms.fetch(direction) { @transforms[direction] = build_transform(direction) }
        end

        private

        def build_transform(direction)
          blocks = @blocks[direction]
          return if @renames.empty? && blocks.empty?

          if direction == :up
            ->(resource) do
              apply_renames(resource, :up)
              blocks.each { it.call(resource) }
            end
          else
            ->(resource) do
              blocks.each { it.call(resource) }
              apply_renames(resource, :down)
            end
          end
        end

        def apply_renames(resource, direction)
          attributes = resource[:attributes]
          return unless attributes.is_a?(Hash)

          @renames.each do |rename|
            source, target =
              direction == :up ? [rename[:from], rename[:to]] : [rename[:to], rename[:from]]
            next unless attributes.key?(source)
            value = attributes.delete(source)
            converter = rename[direction]
            attributes[target] = converter ? converter.call(value) : value
          end
        end
      end

      private_class_method :new

      class << self
        def version(value = nil)
          @version = ApiVersion.parse(value) if value
          @version
        end

        def description(text = nil)
          @description = text if text
          @description
        end

        def resource(type, &block)
          changes = resource_transforms[type.to_s] ||= ResourceChanges.new
          changes.instance_eval(&block)
        end

        def document(&block)
          @document_changes ||= ResourceChanges.new
          @document_changes.instance_eval(&block)
        end

        # Targeted in the Rails route dialect — `controller:` path string +
        # `action:` — the exact pair `url_for` resolves (yielding the real path
        # for docs and teaching bodies) and validates (unroutable pairs raise at
        # use). `replacement:` takes the same shape.
        def removed_endpoint(controller:, action:, replacement: nil)
          removed_endpoints << { controller: controller.to_s, action: action.to_sym, replacement: }
        end

        def removed_endpoints = @removed_endpoints ||= []

        def transform_for(direction, type:) = resource_transforms[type.to_s]&.transform(direction)
        def document_transform(direction) = @document_changes&.transform(direction)
        def field_renames_for(type) = resource_transforms[type.to_s]&.field_renames || {}
        def attribute_renames_for(type) = resource_transforms[type.to_s]&.attribute_renames || []
        def sort_renames_for(type) = resource_transforms[type.to_s]&.sort_renames || {}
        def filter_renames_for(type) = resource_transforms[type.to_s]&.filter_renames || {}
        def resource_types = resource_transforms.keys

        private

        def resource_transforms = @resource_transforms ||= {}
      end
    end
  end
end
