# frozen_string_literal: true

# Short-circuits the per-post reactions method with batch precomputed data
# to avoid N+1 queries from discourse-reactions.
module NestedReplies::PostSerializerReactionsPatch
  def reactions
    if SiteSetting.nested_replies_enabled && object.respond_to?(:precomputed_reactions) &&
         (data = object.precomputed_reactions)
      return data
    end
    super
  end
end

PostSerializer.prepend(NestedReplies::PostSerializerReactionsPatch)
