# frozen_string_literal: true

class ContentLocalization
  # Builds, per post, the localized title/preview for internal topic oneboxes
  # whose linked topic or post has a translation in the reader's locale and that
  # the reader is allowed to see. The frontend swaps this text into the onebox
  # card for original posts the reader sees in their own language (see the
  # localized-oneboxes cooked decorator). Posts shown translated already carry
  # localized cards baked into their cooked HTML (see LocalizedCookedPostProcessor),
  # so they are skipped here.
  #
  # Returns { post_id => [{ topic_id:, post_number:, title:, excerpt: }, ...] }.
  # title and excerpt are each present only when that part has a translation, so
  # a translated title can sit above an untranslated preview.
  #
  # NOTE: this deliberately does not honour the "show original" preference — the
  # guardian passed in (from TopicView) has no request, so it cannot read the
  # anonymous show-original cookie. PostSerializer#include_localized_oneboxes? is
  # the authoritative gate for that (it has the request-aware scope). Any new
  # caller must apply the same gate.
  class OneboxLocalizer
    def self.build(...)
      new(...).build
    end

    # @param posts [Array<Post>] the posts on the page
    # @param guardian [Guardian] the reader's guardian (visibility only)
    # @param category [Category, nil] the category of the topic being viewed
    # @param locale the reader's locale
    def initialize(posts:, guardian:, category:, locale: I18n.locale)
      @posts = posts
      @guardian = guardian
      @category = category
      @locale = locale
    end

    def build
      # Skip only posts actually rendered with their translated cooked (which
      # already carries Path-1-localized cards) — i.e. the same condition as
      # PostSerializer#is_localized. A post that is eligible for translation but
      # has none is still served with its original cooked (BasicPostSerializer
      # falls back), so its oneboxes still need localizing here.
      source_posts =
        @posts.reject do |post|
          ContentLocalization.show_translated_post?(post, @guardian) &&
            post.has_localization?(@locale)
        end
      return {} if source_posts.empty?

      # Internal links the reader's post points at, excluding inbound reflections.
      # We deliberately do not filter on the `quote` flag: an internal onebox
      # card is only `quote: true` once it has been re-extracted from the baked
      # cooked, so a freshly rebaked post can carry `quote: false` for a real
      # card. The frontend decorator is the authority — it only swaps actual
      # `aside.quote` cards — so any extra inline-link rows here are harmless.
      links =
        TopicLink
          .where(post_id: source_posts.map(&:id), internal: true, reflection: false)
          .where.not(link_topic_id: nil)
          .pluck(:post_id, :link_topic_id, :link_post_id)
          .uniq
      return {} if links.empty?

      topic_ids = links.map { |l| l[1] }.uniq
      topics_by_id =
        Topic
          .where(id: topic_ids, archetype: Archetype.default, deleted_at: nil)
          .includes(:category)
          .index_by(&:id)

      linked_posts = linked_posts_for(links)
      visible_topic_ids = topics_by_id.values.select { |topic| visible?(topic) }.map(&:id).to_set
      titles = localized_titles(topic_ids)
      cooked = localized_cooked(linked_posts.values.map(&:id).uniq)

      result = {}

      links.each do |source_post_id, link_topic_id, link_post_id|
        topic = topics_by_id[link_topic_id]
        next if topic.nil? || !visible_topic_ids.include?(topic.id)

        linked_post = linked_posts[link_post_id || [:first, link_topic_id]]
        next if linked_post.nil? || linked_post.topic_id != topic.id

        title =
          if ContentLocalization.show_translated_topic?(topic, @guardian)
            titles[topic.id].presence
          end

        excerpt_cooked =
          if ContentLocalization.show_translated_post?(linked_post, @guardian)
            cooked[linked_post.id].presence
          end

        next if title.blank? && excerpt_cooked.blank?

        entry = { topic_id: topic.id, post_number: linked_post.post_number }
        # escape + emoji like the baked card; the frontend assigns this via innerHTML
        entry[:title] = PrettyText.unescape_emoji(CGI.escapeHTML(title)) if title.present?
        entry[:excerpt] = excerpt_for(linked_post, excerpt_cooked) if excerpt_cooked.present?

        (result[source_post_id] ||= []) << entry
      end

      result
    end

    private

    # Resolves each link's target post. A null link_post_id is a normal shape for
    # topic-level/legacy links (see TopicLink.apply_link_visibility_filters); we
    # fall back to the topic's first post, matching how the card itself renders.
    # The frontend matches on post_number, so this never mis-swaps a card that
    # points at a now-deleted specific post.
    def linked_posts_for(links)
      by_post_id =
        Post.where(
          id: links.filter_map { |l| l[2] }.uniq,
          post_type: Oneboxer.allowed_post_types,
          hidden: false,
          deleted_at: nil,
        ).index_by(&:id)

      nil_topic_ids = links.select { |l| l[2].nil? }.map { |l| l[1] }.uniq
      if nil_topic_ids.present?
        Post
          .where(
            topic_id: nil_topic_ids,
            post_type: Oneboxer.allowed_post_types,
            hidden: false,
            deleted_at: nil,
          )
          .select("DISTINCT ON (topic_id) *")
          .order(:topic_id, :post_number)
          .each { |post| by_post_id[[:first, post.topic_id]] = post }
      end

      by_post_id
    end

    def visible?(topic)
      same_category = @category&.id.present? && @category.id == topic.category_id
      (same_category ? @guardian : anon_guardian).can_see_topic?(topic)
    end

    def anon_guardian
      @anon_guardian ||= Guardian.new
    end

    def localized_titles(topic_ids)
      prefer_exact(
        TopicLocalization
          .where(topic_id: topic_ids)
          .matching_locale(@locale)
          .pluck(:topic_id, :locale, :title),
      )
    end

    def localized_cooked(post_ids)
      prefer_exact(
        PostLocalization
          .where(post_id: post_ids)
          .matching_locale(@locale)
          .pluck(:post_id, :locale, :cooked),
      )
    end

    # matching_locale is a language-prefix match (no site-default fallback — fall
    # back to the original, never another language). When both an exact and a
    # regional row match (e.g. ja and ja_JP for a ja reader), prefer the exact.
    def prefer_exact(rows)
      locale_str = @locale.to_s.sub("-", "_")
      rows.each_with_object({}) do |(id, row_locale, value), acc|
        acc[id] = value if acc[id].nil? || row_locale == locale_str
      end
    end

    def excerpt_for(post, cooked)
      PrettyText.unescape_emoji(
        Post.excerpt(cooked, SiteSetting.post_onebox_maxlength, keep_svg: true, post: post),
      )
    end
  end
end
