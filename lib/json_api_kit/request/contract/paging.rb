# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      module Paging
        extend ActiveSupport::Concern

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

            validate :check_cursors, if: -> { raw_cursors.present? }
            validate :check_cursor_ordering,
                     if: -> { cursors.present? && ordering && resource.sortable_by?(ordering:) }

            def cursor? = after.present? || before.present?

            def cursor_name = after.present? ? :after : :before

            def window? = window_names.present?

            def window_names
              { before_size:, after_size:, include_anchor: }.compact.keys.map { "page[#{it}]" }
            end

            private

            def cursors
              raw_cursors
                .select { |_, raw| Pagination::Cursor.valid?(raw) }
                .transform_values { Pagination::Cursor.parse(it) }
            end

            def resource = options[:resource]

            def raw_sort = options[:raw_parameters][:sort]

            def ordering = raw_sort.nil? ? {} : INDIFFERENT_HASH.cast(raw_sort)

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
                .each_key { errors.add(it, :not_the_sort, message: "not the sort") }
            end
          end
        end
      end
    end
  end
end
