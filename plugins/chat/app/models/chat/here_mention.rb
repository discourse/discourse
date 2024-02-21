# frozen_string_literal: true

module Chat
  class HereMention < Mention
    def identifier
      "here"
    end
  end
end
