# frozen_string_literal: true

class WebHook < ActiveRecord::Base
  has_and_belongs_to_many :web_hook_event_types
  has_and_belongs_to_many :groups
  has_and_belongs_to_many :categories
  has_and_belongs_to_many :tags

  has_many :web_hook_events, dependent: :destroy
  has_many :redelivering_webhook_events
  has_many :web_hook_events_daily_aggregates, dependent: :destroy

  default_scope { order("id ASC") }

  validates :payload_url, presence: true, format: URI.regexp(%w[http https])
  validates :secret, length: { minimum: 12 }, allow_blank: true
  validates_presence_of :content_type
  validates_presence_of :last_delivery_status
  validates_presence_of :web_hook_event_types, unless: :wildcard_web_hook?
  validate :ensure_payload_url_allowed, if: :payload_url_changed?

  before_save :strip_url

  def tag_names=(tag_names_arg)
    DiscourseTagging.add_or_create_tags_by_name(self, tag_names_arg, unlimited: true)
  end

  def self.content_types
    @content_types ||= Enum.new("application/json" => 1, "application/x-www-form-urlencoded" => 2)
  end

  def self.last_delivery_statuses
    @last_delivery_statuses ||= Enum.new(inactive: 1, failed: 2, successful: 3, disabled: 4)
  end

  def self.default_event_types
    WebHookEventType.where(
      id: [
        WebHookEventType::TYPES[:post_created],
        WebHookEventType::TYPES[:post_edited],
        WebHookEventType::TYPES[:post_destroyed],
        WebHookEventType::TYPES[:post_recovered],
        WebHookEventType::TYPES[:category_experts_approved],
        WebHookEventType::TYPES[:category_experts_unapproved],
      ],
    )
  end

  def strip_url
    self.payload_url = (payload_url || "").strip.presence
  end

  EVENT_NAME_TO_EVENT_TYPE_MAP = {
    /\Atopic_\w+_status_updated\z/ => "topic_edited",
    "reviewable_score_updated" => "reviewable_updated",
    "reviewable_transitioned_to" => "reviewable_updated",
  }

  def self.translate_event_name_to_type(event_name)
    EVENT_NAME_TO_EVENT_TYPE_MAP.each do |key, value|
      if key.is_a?(Regexp)
        return value if event_name.to_s =~ key
      else
        return value if event_name.to_s == key
      end
    end
    event_name.to_s
  end

  def self.active_web_hooks(event)
    event_type = translate_event_name_to_type(event)

    WebHook
      .where(active: true)
      .joins(:web_hook_event_types)
      .where("web_hooks.wildcard_web_hook = ? OR web_hook_event_types.name = ?", true, event_type)
      .distinct
  end

  def self.enqueue_hooks(type, event, opts = {})
    active_web_hooks(event).each do |web_hook|
      Jobs.enqueue(
        :emit_web_hook_event,
        opts.merge(web_hook_id: web_hook.id, event_name: event.to_s, event_type: type.to_s),
      )
    end
  end

  def self.enqueue_object_hooks(type, object, event, serializer = nil, opts = {})
    if active_web_hooks(event).exists?
      payload = WebHook.generate_payload(type, object, serializer)

      WebHook.enqueue_hooks(type, event, opts.merge(id: object.id, payload: payload))
    end
  end

  def self.enqueue_topic_hooks(event, topic, payload = nil)
    if active_web_hooks(event).exists? && topic.present?
      payload ||=
        begin
          topic_view = TopicView.new(topic.id, Discourse.system_user, skip_staff_action: true)
          WebHook.generate_payload(:topic, topic_view, WebHookTopicViewSerializer)
        end

      WebHook.enqueue_hooks(
        :topic,
        event,
        id: topic.id,
        category_id: topic.category_id,
        tag_ids: topic.tags.pluck(:id),
        payload: payload,
      )
    end
  end

  def self.enqueue_post_hooks(event, post, payload = nil)
    if active_web_hooks(event).exists? && post.present?
      payload ||= WebHook.generate_payload(:post, post)

      WebHook.enqueue_hooks(
        :post,
        event,
        id: post.id,
        category_id: post.topic&.category_id,
        tag_ids: post.topic&.tags&.pluck(:id),
        payload: payload,
      )
    end
  end

  def self.generate_payload(type, object, serializer = nil)
    serializer ||= TagSerializer if type == :tag
    serializer ||= "WebHook#{type.capitalize}Serializer".constantize

    serializer.new(object, scope: self.guardian, root: false).to_json
  end

  private

  def self.guardian
    Guardian.new(Discourse.system_user)
  end

  # This check is to improve UX
  # IPs are re-checked at request time
  def ensure_payload_url_allowed
    return if payload_url.blank?
    uri = URI(payload_url.strip)

    allowed =
      begin
        FinalDestination::SSRFDetector.lookup_and_filter_ips(uri.hostname).present?
      rescue FinalDestination::SSRFDetector::DisallowedIpError
        false
      end

    self.errors.add(:base, I18n.t("webhooks.payload_url.blocked_or_internal")) if !allowed
  end
end

# == Schema Information
#
# Table name: web_hooks
#
#  id                   :integer          not null, primary key
#  payload_url          :string           not null
#  content_type         :integer          default(1), not null
#  last_delivery_status :integer          default(1), not null
#  status               :integer          default(1), not null
#  secret               :string           default("")
#  wildcard_web_hook    :boolean          default(FALSE), not null
#  verify_certificate   :boolean          default(TRUE), not null
#  active               :boolean          default(FALSE), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
