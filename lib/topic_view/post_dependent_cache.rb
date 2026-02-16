# frozen_string_literal: true

# Extracted from TopicView to make post-dependent memoization self-maintaining.
#
# Any method in TopicView (or a plugin) that caches data derived from @posts
# can register itself with `memoize_for_posts`. When @posts is replaced via
# the `posts=` writer, all registered caches are automatically cleared —
# no hardcoded ivar list required.
#
# This also provides the `skip_post_loading` initializer option so that
# callers who supply their own post set (e.g. nested-replies plugin) can
# skip the default post-loading pipeline entirely instead of loading posts
# and then immediately discarding them.
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

  # The single write path for replacing @posts.
  # Clears all registered post-dependent caches automatically.
  def posts=(new_posts)
    @posts = new_posts
    self.class.post_dependent_ivars.each do |ivar|
      remove_instance_variable(ivar) if instance_variable_defined?(ivar)
    end
  end
end
