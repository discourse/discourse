class UserAuthTokenSerializer < ApplicationSerializer
  include UserAuthTokensMixin

  attributes :seen_at
end
