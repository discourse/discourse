# frozen_string_literal: true

module DiscourseSolved::PostSerializerExtension
  extend ActiveSupport::Concern

  private

  def topic
    topic_view&.topic || object.topic
  end
end
