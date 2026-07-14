# frozen_string_literal: true

class BrowserPageviewEventScore < ActiveRecord::Base
  belongs_to :event, class_name: "BrowserPageviewEvent"
end

# == Schema Information
#
# Table name: browser_pageview_event_scores
#
#  id                  :bigint           not null, primary key
#  automation_ua_score :integer          default(0), not null
#  churn_score         :integer          default(0), not null
#  known_asn_score     :integer          default(0), not null
#  rapid_nav_score     :integer          default(0), not null
#  referrer_score      :integer          default(0), not null
#  velocity_score      :integer          default(0), not null
#  event_id            :bigint           not null
#
# Indexes
#
#  index_browser_pageview_event_scores_on_event_id  (event_id) UNIQUE
#
