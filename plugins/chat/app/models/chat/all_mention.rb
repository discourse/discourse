# frozen_string_literal: true

module Chat
  class AllMention < Mention
    def identifier
      "all"
    end

    def is_mass_mention?
      true
    end
  end
end
