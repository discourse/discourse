class WebHook < ActiveRecord::Base
  has_and_belongs_to_many :web_hook_event_types
  has_and_belongs_to_many :groups
  has_and_belongs_to_many :categories

  has_many :web_hook_events, dependent: :destroy

  default_scope { order('id ASC') }

  validates :payload_url, presence: true, format: URI::regexp(%w(http https))
  validates :secret, length: { minimum: 12 }, allow_blank: true
  validates_presence_of :content_type
  validates_presence_of :last_delivery_status
  validates_presence_of :web_hook_event_types, unless: :wildcard_web_hook?

  before_save :strip_url

  def self.content_types
    @content_types ||= Enum.new('application/json' => 1,
                                'application/x-www-form-urlencoded' => 2)
  end

  def self.last_delivery_statuses
    @last_delivery_statuses ||= Enum.new(inactive: 1,
                                         failed: 2,
                                         successful: 3)
  end

  def self.default_event_types
    [WebHookEventType.find(WebHookEventType::POST)]
  end

  def strip_url
    self.payload_url = (payload_url || "").strip.presence
  end

  def self.active_web_hooks(type)
    WebHook.where(active: true)
      .joins(:web_hook_event_types)
      .where("web_hooks.wildcard_web_hook = ? OR web_hook_event_types.name = ?", true, type.to_s)
      .distinct
  end

  def self.enqueue_hooks(type, opts = {})
    active_web_hooks(type).each do |web_hook|
      Jobs.enqueue(:emit_web_hook_event, opts.merge(
        web_hook_id: web_hook.id, event_type: type.to_s
      ))
    end
  end

  def self.enqueue_object_hooks(type, object, event, serializer = nil)
    if active_web_hooks(type).exists?
      serializer ||= "WebHook#{type.capitalize}Serializer".constantize

      WebHook.enqueue_hooks(type,
        event_name: event.to_s,
        payload: serializer.new(object,
          scope: self.guardian,
          root: false
        ).to_json
      )
    end
  end

  def self.enqueue_topic_hooks(event, topic)
    if active_web_hooks('topic').exists?
      topic_view = TopicView.new(topic.id, Discourse.system_user)

      WebHook.enqueue_hooks(:topic,
        category_id: topic&.category_id,
        event_name: event.to_s,
        payload: WebHookTopicViewSerializer.new(topic_view,
          scope: self.guardian,
          root: false
        ).to_json
      )
    end
  end

  def self.enqueue_post_hooks(event, post)
    if active_web_hooks('post').exists?
      WebHook.enqueue_hooks(:post,
        category_id: post&.topic&.category_id,
        event_name: event.to_s,
        payload: WebHookPostSerializer.new(post,
          scope: self.guardian,
          root: false
        ).to_json
      )
    end
  end

  private

  def self.guardian
    @guardian ||= Guardian.new(Discourse.system_user)
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
