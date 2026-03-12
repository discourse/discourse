# frozen_string_literal: true

module Migrations
  module Database
    module Schema
      module Helpers
        # Canonical datatypes after normalization (used in resolved schema validation)
        VALID_DATATYPES = %i[blob boolean date datetime float inet integer json numeric text].freeze

        # Pre-normalization aliases that map to a canonical datatype
        DATATYPE_ALIASES = {
          binary: :blob,
          string: :text,
          enum: :text,
          uuid: :text,
          jsonb: :json,
        }.freeze

        # All types accepted as DSL type overrides (pre-normalization)
        VALID_TYPE_OVERRIDES =
          (VALID_DATATYPES.map(&:to_s) + DATATYPE_ALIASES.keys.map(&:to_s)).to_set.freeze

        SQLITE_KEYWORDS = %w[
          abort
          action
          add
          after
          all
          alter
          always
          analyze
          and
          as
          asc
          attach
          autoincrement
          before
          begin
          between
          by
          cascade
          case
          cast
          check
          collate
          column
          commit
          conflict
          constraint
          create
          cross
          current
          current_date
          current_time
          current_timestamp
          database
          default
          deferrable
          deferred
          delete
          desc
          detach
          distinct
          do
          drop
          each
          else
          end
          escape
          except
          exclude
          exclusive
          exists
          explain
          fail
          filter
          first
          following
          for
          foreign
          from
          full
          generated
          glob
          group
          groups
          having
          if
          ignore
          immediate
          in
          index
          indexed
          initially
          inner
          insert
          instead
          intersect
          into
          is
          isnull
          join
          key
          last
          left
          like
          limit
          match
          materialized
          natural
          no
          not
          nothing
          notnull
          null
          nulls
          of
          offset
          on
          or
          order
          others
          outer
          over
          partition
          plan
          pragma
          preceding
          primary
          query
          raise
          range
          recursive
          references
          regexp
          reindex
          release
          rename
          replace
          restrict
          returning
          right
          rollback
          row
          rows
          savepoint
          select
          set
          table
          temp
          temporary
          then
          ties
          to
          transaction
          trigger
          unbounded
          union
          unique
          update
          using
          vacuum
          values
          view
          virtual
          when
          where
          window
          with
          without
        ].freeze
        private_constant :SQLITE_KEYWORDS

        def self.escape_identifier(identifier)
          if SQLITE_KEYWORDS.include?(identifier)
            %Q("#{identifier}")
          else
            identifier
          end
        end

        def self.to_singular_classname(snake_case_string)
          snake_case_string.downcase.singularize.camelize
        end

        def self.to_const_name(name)
          name.parameterize.underscore.upcase
        end

        def self.db_label(namespace)
          namespace.split("::").last
        end

        def self.format_ruby_file(path)
          system(
            "bundle",
            "exec",
            "stree",
            "write",
            path,
            exception: true,
            out: File::NULL,
            err: File::NULL,
          )
        rescue StandardError
          raise "Failed to run `bundle exec stree write '#{path}'`"
        end

        def self.format_ruby_files(directory)
          format_ruby_file(File.join(directory, "*.rb"))
        end

        # Plugin directory names use hyphens (discourse-ai), but Ruby symbols
        # use underscores (discourse_ai). Normalize for manifest lookups.
        def self.normalize_plugin_name(name)
          name.to_s.tr("_", "-")
        end
      end
    end
  end
end
