# frozen_string_literal: true

class WebHookEvent < ActiveRecord::Base
  scope :successful, -> { where("status >= 200 AND status <= 299") }
  scope :failed, -> { where("status < 200 OR status > 299") }
  scope :not_ping, -> { where("status <> 0") }
  belongs_to :web_hook

  has_one :redelivering_webhook_event, class_name: "RedeliveringWebhookEvent"

  after_save :update_web_hook_delivery_status

  default_scope { order("created_at DESC") }

  def self.purge_old
    where("created_at < ?", SiteSetting.retain_web_hook_events_period_days.days.ago).delete_all
  end

  def update_web_hook_delivery_status
    web_hook.last_delivery_status =
      case status
      when 200..299
        WebHook.last_delivery_statuses[:successful]
      else
        WebHook.last_delivery_statuses[:failed]
      end
    web_hook.save!
  end
end

# == Schema Information
#
# Table name: web_hook_events
#
#  id               :bigint           not null, primary key
#  duration         :integer          default(0)
#  headers          :string
#  payload          :text
#  response_body    :text
#  response_headers :string
#  status           :integer          default(0)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  web_hook_id      :integer          not null
#
# Indexes
#
#  index_web_hook_events_on_created_at   (created_at)
#  index_web_hook_events_on_web_hook_id  (web_hook_id)
#
