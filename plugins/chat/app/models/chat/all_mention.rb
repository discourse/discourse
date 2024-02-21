# frozen_string_literal: true

module Chat
  class AllMention < Mention
    def identifier
      "all"
    end
  end
end
