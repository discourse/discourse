# frozen_string_literal: true

module PageObjects
  module Components
    module Chat
      class ThreadList < PageObjects::Components::Base
        SELECTOR = ".chat-thread-list"

        def component
          find(SELECTOR)
        end

        def has_loaded?
          component.has_css?(".spinner", wait: 0)
          component.has_no_css?(".spinner")
        end

        def open_thread(thread)
          item_by_id(thread.id).click
        end

        def has_thread?(thread)
          item_by_id(thread.id)
        end

        def has_threads?(count:)
          component.has_css?(".chat-thread-list-item", count: count)
        end

        def has_no_thread?(thread)
          component.has_no_css?(item_by_id_selector(thread.id))
        end

        def item_by_id(id)
          component.find(item_by_id_selector(id), visible: :all)
        end

        def avatar_selector(user)
          ".chat-thread-list-item__om-user-avatar .chat-user-avatar .chat-user-avatar__container[data-user-card=\"#{user.username}\"] img"
        end

        def last_reply_datetime_selector(last_reply)
          ".chat-thread-list-item__last-reply .relative-date[data-time='#{(last_reply.created_at.iso8601.to_time.to_f * 1000).to_i}']"
        end

        def has_no_unread_item?(id)
          component.has_no_css?(item_by_id_selector(id) + ".-is-unread")
        end

        def has_unread_item?(id, count: nil)
          if count.nil?
            component.has_css?(item_by_id_selector(id) + ".-is-unread")
          else
            component.has_css?(
              item_by_id_selector(id) +
                ".-is-unread .chat-thread-list-item-unread-indicator__number",
              text: count.to_s,
            )
          end
        end

        def has_no_unread_item?(id)
          component.has_no_css?(item_by_id_selector(id) + ".-is-unread")
        end

        def item_by_id_selector(id)
          ".chat-thread-list__items .chat-thread-list-item[data-thread-id=\"#{id}\"]"
        end
      end
    end
  end
end
