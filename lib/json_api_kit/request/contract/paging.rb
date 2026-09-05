# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      module Paging
        extend ActiveSupport::Concern

        class AnchorType < ActiveModel::Type::Value
          def cast_value(value) = Array(value)
        end

        included do
          attribute :page, :hash do
            include RawAttributes

            delegate :max_page_size, to: :resource

            attribute :size, :integer
            attribute :after, :string
            attribute :before, :string
            attribute :before_size, :integer
            attribute :after_size, :integer
            attribute :include_anchor, :boolean
            attribute :item_cursors, :boolean
            attribute :anchor, AnchorType.new

            validates :size,
                      numericality: {
                        only_integer: true,
                        greater_than: 0,
                        less_than_or_equal_to: :max_page_size,
                      },
                      unless: -> { size_before_type_cast.nil? }
            validates :before_size,
                      numericality: {
                        only_integer: true,
                        greater_than_or_equal_to: 0,
                      },
                      unless: -> { before_size_before_type_cast.nil? }
            validates :after_size,
                      numericality: {
                        only_integer: true,
                        greater_than_or_equal_to: 0,
                      },
                      unless: -> { after_size_before_type_cast.nil? }
            validates :window_size,
                      numericality: {
                        greater_than: 0,
                        less_than_or_equal_to: :max_page_size,
                      },
                      allow_nil: true
            validates :after, absence: true, if: -> { before.present? }
            validates :before, absence: true, if: -> { after.present? }
            validates :anchor, length: { is: 1 }, allow_nil: true
            validates :anchor, absence: true, if: -> { cursor? }
            validates :anchor, presence: true, if: -> { window? }

            validate :check_cursors, if: -> { raw_cursors.present? }
            validate :check_cursor_ordering, if: -> { cursors.present? && sortable? }
            validate :check_anchor_name, if: -> { anchor.present? }
            validate :check_anchor_value, if: -> { anchor.present? }
            validate :check_anchor_ordering, if: -> { anchor.present? && sortable? }

            def cursor? = after.present? || before.present?

            def cursor_name = after.present? ? :after : :before

            def window? = window_names.present?

            def window_names
              { before_size:, after_size:, include_anchor: }.compact.keys
            end

            private

            def cursors
              raw_cursors
                .select { |_, raw| Pagination::Cursor.valid?(raw) }
                .transform_values { Pagination::Cursor.parse(it) }
            end

            def resource = options[:resource]

            def raw_sort = options[:raw_parameters][:sort]

            def ordering = raw_sort.nil? ? {} : Sorting::SORT.cast(raw_sort)

            def sortable?
              return false unless ordering
              ordering.values.all? { it.in?(Sorting::DIRECTIONS.values) } &&
                resource.sortable_by?(ordering:)
            end

            def window_size
              return unless before_size || after_size
              before_size.to_i + after_size.to_i + anchor_rows
            end

            def anchor_rows = include_anchor == false ? 0 : 1

            def raw_cursors = { after:, before: }.compact

            def check_cursors
              (raw_cursors.keys - cursors.keys).each do
                errors.add(it, :unreadable_cursor, message: "unreadable cursor")
              end
            end

            def check_cursor_ordering
              cursors
                .reject { |_, cursor| resource.paged_from?(cursor, ordering:) }
                .each_key { errors.add(it, :unreadable_cursor, message: "unreadable cursor") }
            end

            def check_anchor_name
              ([anchor_name.to_s] - resource.anchor_names).each do
                errors.add(
                  :anchor,
                  :no_such_name,
                  name: Name::Anchor.new(value: it.to_s, type: resource.type),
                  message: "no such name",
                )
              end
            end

            def check_anchor_value
              return unless anchor_value.is_a?(Enumerable)
              errors.add(
                :anchor,
                :bad_value,
                name: Name::Anchor.new(value: anchor_name.to_s, type: resource.type),
                message: "bad value",
              )
            end

            def check_anchor_ordering
              return if resource.anchored_by?(anchor_name:, ordering:)
              errors.add(
                :anchor,
                :not_the_sort,
                name: Name::Anchor.new(value: anchor_name.to_s, type: resource.type),
                key:
                  Name::Sort.new(
                    value: resource.order(ordering).leading.name.to_s,
                    type: resource.type,
                  ),
                message: "not the sort",
              )
            end

            def anchor_pair = Array(anchor.to_a.first)

            def anchor_name = anchor_pair.first

            def anchor_value = anchor_pair.last
          end
        end
      end
    end
  end
end
