# frozen_string_literal: true

# Extracted from TopicView to make post-dependent memoization self-maintaining.
#
# Any method in TopicView (or a plugin) that caches data derived from @posts
# can register itself with `memoize_for_posts`. When @posts is replaced via
# `reset_post_collection`, all registered caches are automatically cleared —
# no hardcoded ivar list required.
module TopicView::PostDependentCache
  extend ActiveSupport::Concern

  included do
    # Stores ivar names (as symbols like :@all_post_actions) that should
    # be cleared whenever @posts is replaced.
    class_attribute :post_dependent_ivars, instance_writer: false, default: []
  end

  class_methods do
    # Register a memoized ivar as post-dependent.
    #
    #   memoize_for_posts :all_post_actions
    #   memoize_for_posts :primary_group_names, :@group_names
    #
    # The ivar name defaults to `@<method_name>` but can be overridden
    # for cases where the ivar doesn't match the method name.
    def memoize_for_posts(method_name, ivar_name = nil)
      ivar_name ||= :"@#{method_name}"
      # Use += to avoid mutating a parent class's array
      self.post_dependent_ivars = post_dependent_ivars + [ivar_name]
    end
  end

  # Replaces @posts with a new collection and clears all registered
  # post-dependent caches. Use this instead of writing to @posts directly
  # when you need to swap in a different set of posts (e.g. a plugin that
  # builds its own post tree) after the TopicView has been initialized.
  def reset_post_collection(posts:)
    @posts = posts
    self.class.post_dependent_ivars.each do |ivar|
      remove_instance_variable(ivar) if instance_variable_defined?(ivar)
    end
  end
end
