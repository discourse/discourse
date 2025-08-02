# frozen_string_literal: true

class TopicLocalizationSerializer < ApplicationSerializer
  attributes :id, :topic_id, :locale, :title, :fancy_title
end
