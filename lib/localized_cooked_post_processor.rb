# frozen_string_literal: true

class LocalizedCookedPostProcessor
  include CookedProcessorMixin

  def initialize(post_localization, post, opts = {})
    @post_localization = post_localization
    @post = post
    @opts = opts
    @doc = Loofah.html5_fragment(@post_localization.cooked)
    @cooking_options = @post.cooking_options || {}
    @cooking_options[:topic_id] = @post.topic_id
    @cooking_options = @cooking_options.symbolize_keys
    @model = @post
    @category_id = @post&.topic&.category_id
    @omit_nofollow = @post.omit_nofollow?
    @size_cache = {}
  end

  def post_process
    post_process_oneboxes
    post_process_images
    @post_localization.link_post_uploads(fragments: @doc)
  end

  def html
    @doc.try(:to_html)
  end
end
