# frozen_string_literal: true

module Migrations::Database::IntermediateDB
  module Upload
    SQL = <<~SQL
      INSERT OR IGNORE INTO uploads (
          placeholder_hash,
          filename,
          path,
          data,
          url,
          type,
          description,
          origin,
          user_id
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    SQL

    class << self
      def create_for_file!(path:, filename:, type: nil, description: nil, origin: nil, user_id: nil)
        create!(
          placeholder_hash: ::Migrations::ID.hash(path),
          filename:,
          path:,
          type:,
          description:,
          origin:,
          user_id:,
        )
      end

      def create_for_url!(url:, filename:, type: nil, description: nil, origin: nil, user_id: nil)
        create!(
          placeholder_hash: ::Migrations::ID.hash(url),
          filename:,
          url:,
          type:,
          description:,
          origin:,
          user_id:,
        )
      end

      def create_for_data!(data:, filename:, type: nil, description: nil, origin: nil, user_id: nil)
        create!(
          placeholder_hash: ::Migrations::ID.hash(data),
          filename:,
          data: ::Migrations::Database.to_blob(data),
          type:,
          description:,
          origin:,
          user_id:,
        )
      end

      private

      def create!(
        placeholder_hash:,
        filename:,
        path: nil,
        data: nil,
        url: nil,
        type: nil,
        description: nil,
        origin: nil,
        user_id: nil
      )
        ::Migrations::Database::IntermediateDB.insert(
          SQL,
          placeholder_hash,
          filename,
          path,
          data,
          url,
          type,
          description,
          origin,
          user_id,
        )
      end
    end
  end
end
