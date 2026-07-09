# frozen_string_literal: true
# typed: strict

module AdminDashboard
  module Reports
    # Immutable value object describing a mountable report. Previously a
    # Data.define; now a T::Struct so field types are enforced on
    # construction. Keeps the Data semantics providers and specs rely on:
    # keyword construction, value equality, and `to_h` including the
    # composite key.
    class ResolvedReport < T::Struct
      extend T::Sig

      const :source, String
      const :identifier, String
      const :title, String
      const :description, T.nilable(String)
      const :label, T.nilable(String)
      const :url, T.nilable(String)

      sig { returns(String) }
      def key
        "#{source}:#{identifier}"
      end

      sig { returns(T::Hash[Symbol, T.untyped]) }
      def to_h
        { source:, identifier:, title:, description:, label:, url:, key: }
      end

      sig { params(other: T.untyped).returns(T::Boolean) }
      def ==(other)
        !!(other.is_a?(ResolvedReport) && other.to_h == to_h)
      end

      alias eql? ==

      sig { returns(Integer) }
      def hash
        to_h.hash
      end
    end
  end
end
