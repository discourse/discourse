# frozen_string_literal: true

class SharedAiConversation < ActiveRecord::Base
  DEFAULT_MAX_POSTS = 100
  ARTIFACT_SECURITY_MODES = %w[lax hybrid strict]

  belongs_to :user
  belongs_to :target, polymorphic: true

  validates :user_id, presence: true
  validates :target, presence: true
  validates :context, presence: true
  validates :share_key, presence: true, uniqueness: true

  before_validation :generate_share_key, on: :create

  def self.share_conversation(user, target, max_posts: DEFAULT_MAX_POSTS)
    raise "Target must be a topic for now" if !target.is_a?(Topic)

    conversation = find_by(user: user, target: target)
    conversation_data = build_conversation_data(target, max_posts: max_posts)

    shared =
      if conversation
        conversation.update(**conversation_data)
      else
        conversation = create(user_id: user.id, target: target, **conversation_data)
        conversation.persisted?
      end

    if shared
      share_artifacts(target, max_posts: max_posts)
      ::Jobs.enqueue(:shared_conversation_adjust_upload_security, conversation_id: conversation.id)
    end

    conversation
  end

  def self.destroy_conversation(conversation)
    target_id = conversation.target_id
    target_type = conversation.target_type
    target_topic = conversation.target_topic(with_deleted: true)

    conversation.destroy

    if target_topic
      AiArtifact.where(post: target_topic.posts.with_deleted).update_all(
        "metadata = jsonb_set(COALESCE(metadata, '{}'), '{public}', 'false')",
      )
    end

    ::Jobs.enqueue(
      :shared_conversation_adjust_upload_security,
      target_id: target_id,
      target_type: target_type,
    )
  end

  # Technically this may end up being a chat message
  # but this name works
  class SharedPost
    attr_accessor :user
    attr_reader :id, :user_id, :created_at, :cooked, :agent, :llm_name

    def initialize(post)
      @id = post[:id]
      @user_id = post[:user_id]
      @created_at = DateTime.parse(post[:created_at])
      @cooked = post[:cooked]
      @agent = post[:agent]
      @llm_name = post[:llm_name]
    end
  end

  def populated_context
    return @populated_context if @populated_context
    @populated_context = context.map { |post| SharedPost.new(post.symbolize_keys) }
    populate_user_info!(@populated_context)
    @populated_context
  end

  def to_json
    posts =
      populated_context.map do |post|
        {
          id: post.id,
          cooked: post.cooked,
          username: post.user.username,
          created_at: post.created_at,
          agent: post.agent,
          llm_name: post.llm_name,
        }.compact
      end
    { llm_name: llm_name, share_key: share_key, title: title, posts: posts }
  end

  def url
    "#{Discourse.base_uri}/discourse-ai/ai-bot/shared-ai-conversations/#{share_key}"
  end

  def publicly_visible?
    topic = target_topic
    return false if topic.blank?

    source_guardian = user.guardian
    return false if DiscourseAi::AiBot::EntryPoint.ai_share_error(topic, source_guardian)

    context_post_ids = context.filter_map { |context_post| context_post["id"] }
    return false if context_post_ids.blank?

    posts_by_id = Post.where(id: context_post_ids, topic_id: topic.id).index_by(&:id)
    context_post_ids.all? do |post_id|
      post = posts_by_id[post_id]
      post.present? && source_guardian.can_see?(post)
    end
  end

  def target_topic(with_deleted: false)
    return if target_type != "Topic"

    scope = with_deleted ? Topic.with_deleted : Topic
    scope.find_by(id: target_id)
  end

  def html_excerpt
    html = +""
    populated_context.each do |post|
      text = PrettyText.excerpt(post.cooked, 400, strip_links: true, strip_details: true)
      username = ERB::Util.html_escape(post.user.username)

      html << "<p><b>#{username}</b>: #{text}</p>"
      if html.length > 1000
        html << "<p>...</p>"
        break
      end
    end
    html << "<a href='#{url}'>#{I18n.t("discourse_ai.share_ai.read_more")}</a>"
    html
  end

  def onebox
    escaped_title = ERB::Util.html_escape(title)
    <<~HTML
    <div>
      <aside class="onebox allowlistedgeneric" data-onebox-src="#{url}">
      <header class="source">
        <span class="onebox-ai-llm-title">#{I18n.t("discourse_ai.share_ai.onebox_title", llm_name: llm_name)}</span>
        <a href="#{url}" target="_blank" rel="nofollow ugc noopener" tabindex="-1">#{Discourse.base_uri}</a>
      </header>
      <article class="onebox-body">
      <h3><a href="#{url}" rel="nofollow ugc noopener" tabindex="-1">#{escaped_title}</a></h3>
    #{html_excerpt}
    </article>
    <div style="clear: both"></div>
    </aside>
    </div>
    HTML
  end

  def self.excerpt(posts)
    excerpt = +""
    posts.each do |post|
      excerpt << "#{post.user.display_name}: #{post.excerpt(100)} "
      break if excerpt.length > 1000
    end
    excerpt
  end

  def formatted_excerpt
    I18n.t("discourse_ai.share_ai.formatted_excerpt", llm_name: llm_name, excerpt: excerpt)
  end

  def self.build_conversation_data(topic, max_posts: DEFAULT_MAX_POSTS, include_usernames: false)
    allowed_user_ids = topic.topic_allowed_users.pluck(:user_id)
    legacy_participant = DiscourseAi::AiBot::EntryPoint.find_participant_in(allowed_user_ids)
    legacy_llm_name =
      ActiveSupport::Inflector.humanize(legacy_participant&.llm) if legacy_participant

    posts = conversation_posts(topic, max_posts: max_posts).to_a
    Post.preload_custom_fields(
      posts,
      [
        DiscourseAi::AiBot::POST_AI_LLM_NAME_FIELD,
        DiscourseAi::AiBot::POST_AI_LLM_MODEL_ID_FIELD,
        DiscourseAi::AiBot::POST_AI_AGENT_ID_FIELD,
      ],
    )
    agent_ids =
      posts.filter_map do |post|
        post.custom_fields[DiscourseAi::AiBot::POST_AI_AGENT_ID_FIELD].presence&.to_i
      end
    agent_names = AiAgent.where(id: agent_ids).pluck(:id, :name).to_h
    unknown_model = I18n.t("discourse_ai.unknown_model")
    historical_bot_user_ids = DiscourseAi::AiBot::EntryPoint.historical_bot_user_ids(topic: topic)

    mapped_posts =
      posts.map do |post|
        ai_response = historical_bot_user_ids.include?(post.user_id)
        agent_id = post.custom_fields[DiscourseAi::AiBot::POST_AI_AGENT_ID_FIELD].presence&.to_i
        llm_name =
          post.custom_fields[DiscourseAi::AiBot::POST_AI_LLM_NAME_FIELD].presence if ai_response
        llm_name ||= legacy_llm_name if ai_response && legacy_participant&.id == post.user_id
        llm_name ||= unknown_model if ai_response && agent_id.blank?
        agent_name = agent_names[agent_id] if ai_response

        {
          id: post.id,
          user_id: post.user_id,
          created_at: post.created_at,
          cooked: cook_artifacts(post),
          agent: agent_name,
          llm_name: llm_name,
          username: include_usernames ? post.user&.username : nil,
        }.compact
      end

    response_model_names = mapped_posts.filter_map { |post| post[:llm_name] }.uniq
    llm_name =
      if response_model_names.one?
        response_model_names.first
      elsif response_model_names.many?
        I18n.t("discourse_ai.multiple_models")
      else
        unknown_model
      end

    { llm_name: llm_name, title: topic.title, excerpt: excerpt(posts), context: mapped_posts }
  end

  def self.cook_artifacts(post)
    html = post.cooked
    return html if !ARTIFACT_SECURITY_MODES.include?(SiteSetting.ai_artifact_security)

    doc = Nokogiri::HTML5.fragment(html)
    doc
      .css("div.ai-artifact")
      .each do |node|
        id = node["data-ai-artifact-id"].to_i
        version = node["data-ai-artifact-version"]
        version_number = version.to_i if version
        node.replace(AiArtifact.iframe_for(id, version_number)) if id > 0
      end

    doc.to_s
  end

  def self.share_artifacts(topic, max_posts: DEFAULT_MAX_POSTS)
    return if !ARTIFACT_SECURITY_MODES.include?(SiteSetting.ai_artifact_security)

    conversation_posts(topic, max_posts: max_posts).each do |post|
      doc = Nokogiri::HTML5.fragment(post.cooked)
      doc
        .css("div.ai-artifact")
        .each do |node|
          id = node["data-ai-artifact-id"].to_i
          AiArtifact.share_publicly(id: id, post: post) if id > 0
        end
    end
  end

  def self.conversation_posts(topic, max_posts: DEFAULT_MAX_POSTS)
    topic
      .posts
      .by_post_number
      .where(post_type: Post.types[:regular])
      .where.not(cooked: nil)
      .where(deleted_at: nil)
      .limit(max_posts)
  end

  private

  def populate_user_info!(posts)
    users = User.where(id: posts.map(&:user_id).uniq).index_by(&:id)
    posts.each { |post| post.user = users[post.user_id] }
  end

  def generate_share_key
    self.share_key = SecureRandom.urlsafe_base64(16)
  end
end

# == Schema Information
#
# Table name: shared_ai_conversations
#
#  id          :bigint           not null, primary key
#  context     :jsonb            not null
#  excerpt     :string           not null
#  llm_name    :string           not null
#  share_key   :string           not null
#  target_type :string           not null
#  title       :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  target_id   :integer          not null
#  user_id     :integer          not null
#
# Indexes
#
#  idx_shared_ai_conversations_user_target                     (user_id,target_id,target_type) UNIQUE
#  index_shared_ai_conversations_on_share_key                  (share_key) UNIQUE
#  index_shared_ai_conversations_on_target_id_and_target_type  (target_id,target_type) UNIQUE
#
