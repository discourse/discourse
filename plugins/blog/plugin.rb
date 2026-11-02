# frozen_string_literal: true

# name: blog
# about: A lightweight publication with Discourse authoring and live discussion.
# version: 0.1.0
# authors: Discourse
# url: https://github.com/discourse/discourse/tree/main/plugins/blog
# required_version: 3.6.0

enabled_site_setting :blog_enabled
register_asset "stylesheets/blog-editor.scss"
register_asset "stylesheets/blog-publication-panel.scss"
register_asset "stylesheets/blog-review.scss"
register_asset "stylesheets/blog-post-summary.scss"
register_asset "stylesheets/blog-discussion.scss"
register_asset "stylesheets/admin/blog-admin.scss", :admin
register_svg_icon "pen-to-square"
add_admin_route "blog.admin.title", "blog", use_new_show_route: true

module ::Blog
  PLUGIN_NAME = "blog"
end

require_relative "lib/blog/engine"

register_homepage(
  "blog",
  name: "blog.homepage_option",
  path: "/blog",
  route: "blog/articles#index",
  anonymous: true,
  server_side: true,
  enabled: -> { Blog::Configuration.public_enabled? && !Blog::Configuration.custom_domain? },
)

after_initialize do
  if defined?(Rack::MiniProfiler)
    %w[/blog-highlight/ /blog/blog-highlight/].each do |path|
      Rack::MiniProfiler.config.skip_paths << "#{Discourse.base_path}#{path}"
    end
  end

  add_to_serializer(
    :site,
    :blog_base_url,
    include_condition: -> { UpcomingChanges.enabled?(:blog_enabled) },
  ) { Blog::Configuration.base_url }
  add_to_serializer(:current_user, :can_blog_edit) { Blog::Configuration.contributor?(object) }
  reloadable_patch { ::Guardian.prepend(Blog::GuardianExtensions) }
  reloadable_patch { ::Topic.prepend(Blog::TopicExtensions) }
  if defined?(::Middleware::EnforceHostname)
    reloadable_patch { ::Middleware::EnforceHostname.prepend(Blog::EnforceHostnameExtension) }
  end

  Rails.application.config.filter_parameters += [:review_token]

  add_model_callback(:topic, :before_destroy) do
    Blog::Review.where(topic_id: id).find_each(&:destroy!)
    Blog::Publication
      .where(topic_id: id)
      .or(Blog::Publication.where(draft_topic_id: id))
      .or(Blog::Publication.where(discussion_topic_id: id))
      .find_each(&:destroy!)
  end

  add_model_callback(:topic, :validate) do
    if category_id_changed? && persisted? &&
         category_id_in_database == SiteSetting.blog_drafts_category.to_i
      errors.add(:category_id, I18n.t("blog.editorial.private_source"))
    end
  end

  add_model_callback(:post, :after_update) do
    if post_number == 1 &&
         ((saved_change_to_hidden? && hidden?) || (saved_change_to_deleted_at? && deleted_at))
      Blog::Review.revoke_for_topic!(topic_id)
    end
  end

  add_model_callback(:topic, :after_update) do
    if saved_change_to_category_id? || saved_change_to_deleted_at? || saved_change_to_archetype? ||
         saved_change_to_visible?
      Blog::Review.revoke_for_topic!(id)
    end
  end

  add_to_serializer(
    :post,
    :blog_article,
    include_condition: -> do
      object.is_first_post? && object.word_count.to_i >= 250 &&
        Blog::Configuration.public_enabled? &&
        object.topic.category_id == SiteSetting.blog_category.to_i
    end,
  ) do
    if publication =
         Blog::Publication.publicly_visible.find_by(discussion_topic_id: object.topic_id)
      {
        url: publication.url,
        excerpt: publication.display_excerpt,
        blog_name: SiteSetting.blog_title,
      }
    end
  end

  add_to_serializer(
    :topic_view,
    :blog_publication,
    include_condition: -> { !blog_publication.nil? },
  ) do
    unless instance_variable_defined?(:@blog_publication)
      @blog_publication = Blog::PublicationEntry.for_viewer(object.topic, scope.user)
    end
    @blog_publication
  end

  Discourse::Application.routes.prepend(&Blog::Routes::DRAW)

  reloadable_patch { ::TopicView.prepend(Blog::TopicViewExtension) }
end
