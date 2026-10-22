# frozen_string_literal: true

module DiscourseDataExplorer
  module AdminAssistant
    class QueryDraft < DiscourseAi::Agents::Tools::DraftReference
      class << self
        private

        def draft_kind
          "data_explorer_query"
        end
      end
    end
  end
end
