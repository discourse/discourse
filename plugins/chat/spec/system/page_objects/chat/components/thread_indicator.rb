# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class ThreadIndicator < PageObjects::Components::Base
        attr_reader :context

        SELECTOR = ".chat-message-thread-indicator"

        def initialize(context)
          @context = context
        end

        def click
          find("#{@context} #{SELECTOR}").click
        end

        def exists?(**args)
          has_css?("#{@context} #{SELECTOR}")
        end

        def does_not_exist?(**args)
          has_no_css?("#{@context} #{SELECTOR}")
        end

        def has_reply_count?(count)
          has_css?(
            "#{@context} #{SELECTOR}__replies-count",
            text: I18n.t("js.chat.thread.replies", count: count),
          )
        end

        def has_participant?(user)
          has_css?(
            "#{@context} .chat-thread-participants__avatar-group .chat-user-avatar[data-username=\"#{user.username}\"] img",
          )
        end

        def has_no_participants?
          has_no_css?("#{@context} .chat-thread-participants")
        end

        def has_excerpt?(text)
          has_css?("#{@context} #{SELECTOR}__last-reply-excerpt", text: text)
        end

        def has_user?(user)
          has_css?("#{@context} #{SELECTOR}__last-reply-username", text: user.username)
        end

        def excerpt
          find("#{@context} #{SELECTOR}__last-reply-excerpt")
        end
      end
    end
  end
end
