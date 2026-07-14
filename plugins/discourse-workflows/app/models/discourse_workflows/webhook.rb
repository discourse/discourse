# frozen_string_literal: true

module DiscourseWorkflows
  class Webhook < ActiveRecord::Base
    self.table_name = "discourse_workflows_webhooks"

    DYNAMIC_SEGMENT_PATTERN = /\A:([\w\-]+)\z/

    belongs_to :workflow, class_name: "DiscourseWorkflows::Workflow"

    scope :production, -> { where(test_webhook: false) }
    scope :test_listeners, -> { where(test_webhook: true) }
    scope :live, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
    scope :expired, -> { where("expires_at IS NOT NULL AND expires_at <= ?", Time.current) }
    scope :dynamic, -> { where.not(webhook_id: nil) }
    scope :static, -> { where(webhook_id: nil) }

    def self.normalize_method(value)
      value.to_s.upcase
    end

    def self.normalize_path(value)
      value.to_s.delete_prefix("/")
    end

    def self.segments_for(path)
      normalize_path(path).split("/").reject(&:empty?)
    end

    def self.dynamic_path?(path)
      segments_for(path).any? { |segment| segment.match?(DYNAMIC_SEGMENT_PATTERN) }
    end

    def self.path_length_for(path)
      segments_for(path).size
    end

    def self.match_dynamic_path(template:, segments:)
      template_segments = segments_for(template)
      return nil unless template_segments.size == segments.size

      params = {}
      template_segments.zip(segments) do |template_segment, segment|
        if (match = template_segment.match(DYNAMIC_SEGMENT_PATTERN))
          params[match[1]] = segment
        elsif template_segment != segment
          return nil
        end
      end
      params
    end

    def dynamic?
      webhook_id.present?
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_webhooks
#
#  id                  :bigint           not null, primary key
#  expires_at          :datetime
#  http_method         :string(10)       not null
#  node_name           :string(100)      not null
#  path_length         :integer
#  test_webhook        :boolean          default(FALSE), not null
#  webhook_path        :string(500)      not null
#  workflow_snapshot   :jsonb
#  created_at          :datetime         not null
#  user_id             :integer
#  webhook_id          :string(36)
#  workflow_id         :bigint           not null
#  workflow_version_id :string(36)
#
# Indexes
#
#  idx_dwf_webhooks_on_expires_at              (expires_at) WHERE (expires_at IS NOT NULL)
#  idx_dwf_webhooks_on_method_path_test        (http_method,webhook_path,test_webhook) UNIQUE
#  idx_dwf_webhooks_on_webhook_id_method_test  (webhook_id,http_method,test_webhook) WHERE (webhook_id IS NOT NULL)
#  idx_dwf_webhooks_on_workflow_id             (workflow_id)
#  idx_dwf_webhooks_on_workflow_version_id     (workflow_version_id)
#
