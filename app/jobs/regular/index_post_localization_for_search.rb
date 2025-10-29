# frozen_string_literal: true

class Jobs::IndexPostLocalizationForSearch < Jobs::Base
  def execute(args)
    post_id = args[:post_id]
    return if post_id.blank?

    post = Post.find_by(id: post_id)
    return if post.blank?

    SearchIndexer.index_post_localizations(post)
  end
end
