# frozen_string_literal: true

module JsonApiKit
  class Resource
    module Anchoring
      extend ActiveSupport::Concern

      included do
        class_attribute :declared_anchors,
                        default: [].freeze,
                        instance_accessor: false,
                        instance_predicate: false
        private_class_method :declared_anchors, :declared_anchors=
      end

      class_methods do
        def anchor(name, &condition)
          self.declared_anchors = declared_anchors + [Declarations::Anchor.new(name, &condition)]
        end

        def anchor_names = declared_anchors.map(&:name)

        def anchored_by?(anchor_name:, ordering: {})
          declared_anchors
            .detect { it.name == anchor_name.to_s }
            .then { it.nil? || it.locatable_in?(order(ordering)) }
        end

        def anchors(guardian) = Declarations::Anchors.new(declared_anchors, guardian:)
      end
    end
  end
end
