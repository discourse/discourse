# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # One breaking API change, bound to the version (date) that introduced it.
    # Declarative and immutable — it describes a change that happened in the past
    # and is never instantiated. Transforms are pure hash reshapes at the
    # serialization seam: `up` migrates an old client's request document toward
    # latest, `down` migrates a latest response document toward the old shape.
    # See docs/versioning-design.md.
    #
    #   class RenameFooToBar < JsonApiKit::VersionChange
    #     version "2026-06-15"
    #     description "The `foo` attribute of the things resource is renamed to `bar`."
    #
    #     resource :things do
    #       up { |resource| resource[:attributes][:bar] = resource[:attributes].delete(:foo) }
    #       down { |resource| resource[:attributes][:foo] = resource[:attributes].delete(:bar) }
    #     end
    #   end
    class VersionChange
      class TransformSet
        def initialize
          @transforms = {}
        end

        def up(&block) = @transforms[:up] = block
        def down(&block) = @transforms[:down] = block
        def [](direction) = @transforms[direction]
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
          resource_transforms[type.to_s] = TransformSet.new.tap { it.instance_eval(&block) }
        end

        def document(&block)
          @document_transform_set = TransformSet.new.tap { it.instance_eval(&block) }
        end

        def transform_for(direction, type:) = resource_transforms[type.to_s]&.[](direction)
        def document_transform(direction) = @document_transform_set&.[](direction)
        def resource_types = resource_transforms.keys

        private

        def resource_transforms = @resource_transforms ||= {}
      end
    end
  end
end
