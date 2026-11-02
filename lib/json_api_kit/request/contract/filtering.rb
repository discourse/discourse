# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      module Filtering
        extend ActiveSupport::Concern

        included do
          attribute :filter, INDIFFERENT_HASH

          validate :check_filter_names, if: -> { filter.present? }
          validate :check_filter_values, if: -> { filter.present? }
        end

        def to_hash
          return super if filter.blank?
          super.merge(filter: {}).deep_merge(filter_parameters)
        end

        private

        def check_filter_names
          filter_paths.each_key { check_filter_name(it) }
        end

        def check_filter_name(path)
          return if path.declared?
          errors.add(
            :filter,
            :no_such_name,
            name: path.filter,
            parameter_member: path.member_name(glossary),
            message: "no such name",
          )
        end

        def check_filter_values
          filter_paths.each do |path, value|
            next if comparable?(value) || listed?(value)
            errors.add(
              :filter,
              :bad_value,
              name: path.filter,
              parameter_member: path.member_name(glossary),
              message: "bad value",
            )
          end
        end

        def filter_paths
          @filter_paths ||= filter.to_h.transform_keys { FilterPaths::Path.for(it, resource:) }
        end

        def filter_parameters
          @filter_parameters ||=
            filter_paths.reduce({}) do |params, (path, value)|
              params.deep_merge(path.parameters(value))
            end
        end

        def listed?(value) = value.present? && Array.wrap(value).all? { comparable?(it) }
      end
    end
  end
end
