# frozen_string_literal: true

module JsonApiKit
  class Document
    class RelationshipObject
      delegate :pages, to: :linkage, private: true

      def initialize(linkage, urls:, owner:, name:)
        @linkage = linkage
        @urls = urls
        @owner = owner
        @name = name
      end

      def to_h = { data:, links: }

      private

      attr_reader :linkage, :urls, :owner, :name

      def data = linkage.collapse { it.identity.to_h }

      def links = { self: relationship_url.to_s, related: related_url.to_s }.merge(page_links)

      def relationship_url = owner_url.relationship(name)

      def related_url = owner_url.related(name)

      def owner_url = @owner_url ||= urls.for(owner)

      def page_links = PageLinks.new(relationship_url, pages).to_h
    end
  end
end
