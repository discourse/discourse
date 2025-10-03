# frozen_string_literal: true

class SharedAiConversation < ActiveRecord::Base
  DEFAULT_MAX_POSTS = 100

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

    conversation =
      if conversation
        conversation.update(**conversation_data)
        conversation
      else
        create(user_id: user.id, target: target, **conversation_data)
      end

    ::Jobs.enqueue(:shared_conversation_adjust_upload_security, conversation_id: conversation.id)

    conversation
  end

  def self.destroy_conversation(conversation)
    conversation.destroy

    maybe_topic = conversation.target
    if maybe_topic.is_a?(Topic)
      AiArtifact.where(post: maybe_topic.posts).update_all(
        "metadata = jsonb_set(COALESCE(metadata, '{}'), '{public}', 'false')",
      )
    end

    ::Jobs.enqueue(
      :shared_conversation_adjust_upload_security,
      target_id: conversation.target_id,
      target_type: conversation.target_type,
    )
  end

  # Technically this may end up being a chat message
  # but this name works
  class SharedPost
    attr_accessor :user
    attr_reader :id, :user_id, :created_at, :cooked, :persona
    def initialize(post)
      @id = post[:id]
      @user_id = post[:user_id]
      @created_at = DateTime.parse(post[:created_at])
      @cooked = post[:cooked]
      @persona = post[:persona]
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
      self.populated_context.map do |post|
        {
          id: post.id,
          cooked: post.cooked,
          username: post.user.username,
          created_at: post.created_at,
        }
      end
    { llm_name: self.llm_name, share_key: self.share_key, title: self.title, posts: posts }
  end

  def url
    "#{Discourse.base_uri}/discourse-ai/ai-bot/shared-ai-conversations/#{share_key}"
  end

  def html_excerpt
    html = +""
    populated_context.each do |post|
      text = PrettyText.excerpt(post.cooked, 400, strip_links: true, strip_details: true)

      html << "<p><b>#{post.user.username}</b>: #{text}</p>"
      if html.length > 1000
        html << "<p>...</p>"
        break
      end
    end
    html << "<a href='#{url}'>#{I18n.t("discourse_ai.share_ai.read_more")}</a>"
    html
  end

  def onebox
    <<~HTML
    <div>
      <aside class="onebox allowlistedgeneric" data-onebox-src="#{url}">
      <header class="source">
        <span class="onebox-ai-llm-title">#{I18n.t("discourse_ai.share_ai.onebox_title", llm_name: llm_name)}</span>
        <a href="#{url}" target="_blank" rel="nofollow ugc noopener" tabindex="-1">#{Discourse.base_uri}</a>
      </header>
      <article class="onebox-body">
      <h3><a href="#{url}" rel="nofollow ugc noopener" tabindex="-1">#{title}</a></h3>
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
    ai_bot_participant = DiscourseAi::AiBot::EntryPoint.find_participant_in(allowed_user_ids)

    llm_name = ai_bot_participant&.llm

    llm_name = ActiveSupport::Inflector.humanize(llm_name) if llm_name
    llm_name ||= I18n.t("discourse_ai.unknown_model")

    persona = nil
    if persona_id = topic.custom_fields["ai_persona_id"]
      persona = AiPersona.find_by(id: persona_id.to_i)&.name
    end

    posts =
      topic
        .posts
        .by_post_number
        .where(post_type: Post.types[:regular])
        .where.not(cooked: nil)
        .where(deleted_at: nil)
        .limit(max_posts)

    {
      llm_name: llm_name,
      title: topic.title,
      excerpt: excerpt(posts),
      context:
        posts.map do |post|
          mapped = {
            id: post.id,
            user_id: post.user_id,
            created_at: post.created_at,
            cooked: cook_artifacts(post),
          }

          mapped[:persona] = persona if ai_bot_participant&.id == post.user_id
          mapped[:username] = post.user&.username if include_usernames
          mapped
        end,
    }
  end

  def self.cook_artifacts(post)
    html = post.cooked
    return html if !%w[lax hybrid strict].include?(SiteSetting.ai_artifact_security)

    doc = Nokogiri::HTML5.fragment(html)
    doc
      .css("div.ai-artifact")
      .each do |node|
        id = node["data-ai-artifact-id"].to_i
        version = node["data-ai-artifact-version"]
        version_number = version.to_i if version
        if id > 0
          AiArtifact.share_publicly(id: id, post: post)
          node.replace(AiArtifact.iframe_for(id, version_number))
        end
      end

    doc.to_s
  end

  private

  def populate_user_info!(posts)
    users = User.where(id: posts.map(&:user_id).uniq).map { |u| [u.id, u] }.to_h
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
#  user_id     :integer          not null
#  target_id   :integer          not null
#  target_type :string           not null
#  title       :string           not null
#  llm_name    :string           not null
#  context     :jsonb            not null
#  share_key   :string           not null
#  excerpt     :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  idx_shared_ai_conversations_user_target                     (user_id,target_id,target_type) UNIQUE
#  index_shared_ai_conversations_on_share_key                  (share_key) UNIQUE
#  index_shared_ai_conversations_on_target_id_and_target_type  (target_id,target_type) UNIQUE
#
