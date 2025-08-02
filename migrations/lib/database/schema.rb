# frozen_string_literal: true

module Migrations::Database
  module Schema
    Table =
      Data.define(:name, :columns, :indexes, :primary_key_column_names) do
        def sorted_columns
          columns.sort_by { |c| [c.is_primary_key ? 0 : 1, c.name] }
        end
      end
    Column = Data.define(:name, :datatype, :nullable, :max_length, :is_primary_key)
    Index = Data.define(:name, :column_names, :unique, :condition)

    class ConfigError < StandardError
    end

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
    ]

    def self.escape_identifier(identifier)
      if SQLITE_KEYWORDS.include?(identifier)
        %Q("#{identifier}")
      else
        identifier
      end
    end
  end
end
