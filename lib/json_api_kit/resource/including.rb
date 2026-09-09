# frozen_string_literal: true

module JsonApiKit
  class Resource
    module Including
      extend ActiveSupport::Concern

      included do
        class_attribute :declared_include_paths,
                        default: Paths.new([]).freeze,
                        instance_accessor: false,
                        instance_predicate: false
        private_class_method :declared_include_paths, :declared_include_paths=
      end

      class_methods do
        delegate :allow, to: :include_paths
        delegate :include?, to: :include_paths, prefix: :paths

        def includes(*paths)
          self.declared_include_paths = declared_include_paths + Paths.new(paths)
        end

        private

        def include_paths
          Declarations::IncludePaths.new(declared_include_paths, relationships:)
        end
      end
    end
  end
end
