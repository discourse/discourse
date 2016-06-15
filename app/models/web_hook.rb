class WebHook < ActiveRecord::Base
  has_and_belongs_to_many :web_hook_event_types
  has_and_belongs_to_many :groups
  has_and_belongs_to_many :categories

  # TODO: add event models for log
  # has_many :web_hook_events, dependent: :destroy

  default_scope { order('id ASC') }

  validates :payload_url, presence: true, format: URI::regexp(%w(http https))
  validates :secret, length: { minimum: 12 }, allow_blank: true
  validates_presence_of :content_type
  validates_presence_of :last_delivery_status
  validates_presence_of :web_hook_event_types, unless: :wildcard_web_hook?

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
#  created_at           :datetime
#  updated_at           :datetime
#
