# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ArtifactShareKeyValuesController < ArtifactKeyValuesController
      def set
        @artifact.with_lock { super }
      end

      private

      def can_read_all_private_key_values?
        false
      end

      def find_artifact
        @artifact = AiArtifactShare.find_by(share_key: params[:share_key])
        raise Discourse::NotFound if !@artifact&.publicly_visible?
      end
    end
  end
end
