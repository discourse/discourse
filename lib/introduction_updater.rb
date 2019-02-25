class IntroductionUpdater

  def initialize(user)
    @user = user
  end

  def get_summary
    summary_from_post(find_welcome_post)
  end

  def update_summary(new_value)
    post = find_welcome_post
    return unless post

    previous_value = summary_from_post(post).strip

    if previous_value != new_value
      revisor = PostRevisor.new(post)

      remaining = post.raw.split("\n")[1..-1]
      revisor.revise!(@user, raw: "#{new_value}\n#{remaining.join("\n")}")
    end
  end

  protected

  def summary_from_post(post)
    return post ? post.raw.split("\n").first : nil
  end

  def find_welcome_post
    topic_id = TopicCustomField
      .where(name: "is_welcome_topic", value: "true")
      .pluck(:topic_id)

    if topic_id.blank?
      title = I18n.t("discourse_welcome_topic.title")
      topic_id = find_topic_id(title)
    end

    if topic_id.blank?
      title = I18n.t("discourse_welcome_topic.title", locale: :en)
      topic_id = find_topic_id(title)
    end

    if topic_id.blank?
      topic_id = Topic.listable_topics
        .where(pinned_globally: true)
        .order(:created_at)
        .limit(1)
        .pluck(:id)
    end

    welcome_topic = Topic.where(id: topic_id).first
    return nil if welcome_topic.blank?

    welcome_topic.first_post
  end

  def find_topic_id(topic_title)
    slug = Slug.for(topic_title, nil)
    return nil if slug.blank?

    Topic.listable_topics
      .where(slug: slug)
      .pluck(:id)
  end
end
