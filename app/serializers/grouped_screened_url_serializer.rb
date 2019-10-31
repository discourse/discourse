# frozen_string_literal: true

class GroupedScreenedUrlSerializer < ApplicationSerializer
  root 'grouped_screened_url'

  attributes :domain,
             :action,
             :match_count,
             :last_match_at,
             :created_at

  def action
    'do_nothing'
  end
end
