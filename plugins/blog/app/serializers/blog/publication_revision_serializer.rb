# frozen_string_literal: true

module ::Blog
  class PublicationRevisionSerializer < ApplicationSerializer
    attributes :id, :title, :approved_by, :preview_url

    def approved_by
      object.approver&.username
    end

    def preview_url
      "#{@options[:publication].preview_url}?revision_id=#{object.id}"
    end
  end
end
