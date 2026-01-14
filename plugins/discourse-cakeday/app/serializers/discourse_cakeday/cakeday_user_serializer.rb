# frozen_string_literal: true

module DiscourseCakeday
  class CakedayUserSerializer < BasicUserSerializer
    attributes :title, :cakedate
  end
end
