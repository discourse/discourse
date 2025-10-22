# frozen_string_literal: true

module Jobs
  class GenerateChatThreadTitle < ::Jobs::Base
    sidekiq_options queue: "low"

    def execute(args)
      return unless SiteSetting.ai_helper_automatic_chat_thread_title
      return if (thread_id = args[:thread_id]).blank?

      thread = ::Chat::Thread.find_by_id(thread_id)
      return if thread.nil? || thread.title.present?

      title = DiscourseAi::AiHelper::ChatThreadTitler.new(thread).suggested_title
      return if title.blank?

      # TODO use a proper API that will make the new title update live
      thread.update!(title: title)
    end
  end
end
