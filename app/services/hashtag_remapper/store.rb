# frozen_string_literal: true

class HashtagRemapper
  class Store
    def self.key = raise(NotImplementedError)
    def self.relation = raise(NotImplementedError)
    def self.raw_column = raise(NotImplementedError)
    def self.cooked(record) = nil
    def self.cook_options(record) = {}
    def self.hashtag_context = nil
    def self.raw(record) = record.public_send(raw_column)

    def self.write!(record, raw)
      record.public_send(:"#{raw_column}=", raw)
      record.save!(validate: false)
    end

    def self.candidates(old_ref)
      column = "#{relation.table_name}.#{raw_column}"

      relation.where("#{column} ILIKE ?", HashtagRewriter.sql_like_pattern(old_ref))
    end
  end
end
