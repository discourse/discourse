# frozen_string_literal: true

module Chat
  class HereMention < Mention
    def identifier
      "here"
    end

    def is_mass_mention?
      true
    end
  end
end
