# frozen_string_literal: true

module ::PostVoting
  CREATE_AS_POST_VOTING_DEFAULT = "create_as_post_voting_default"
  ONLY_POST_VOTING_IN_THIS_CATEGORY = "only_post_voting_in_this_category"

  class Engine < Rails::Engine
    engine_name "post_voting"
    isolate_namespace PostVoting
  end
end
