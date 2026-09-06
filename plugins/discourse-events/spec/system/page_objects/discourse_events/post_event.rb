# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseEvents
      class PostEvent < PageObjects::Pages::Base
        TRIGGER_MENU_SELECTOR = ".discourse-post-event-more-menu-trigger"

        STATUS_BUTTONS = {
          going: ".going-button",
          interested: ".interested-button",
          not_going: ".not-going-button",
        }.freeze

        def open_more_menu
          try_until_success do
            locator("#{TRIGGER_MENU_SELECTOR}:not(.--saving)").click
            yield if block_given?
          end
          self
        end

        def going
          locator(".going-button").click
          self
        end

        def not_going
          locator(".not-going-button").click
          self
        end

        def has_going_menu?
          has_css?(".discourse-post-event-going-menu-trigger")
        end

        def has_no_going_menu?
          has_no_css?(".discourse-post-event-going-menu-trigger")
        end

        def has_going_button?
          has_css?(".going-button")
        end

        def has_going_status?
          has_css?(".event-status.status-going")
        end

        def has_selected_status?(status)
          has_css?(status_button_selector(status, ".btn-primary"))
        end

        def has_no_selected_status?(status)
          has_no_css?(status_button_selector(status, ".btn-primary"))
        end

        def has_pressed_status?(status, pressed: true)
          has_css?(status_button_selector(status, "[aria-pressed='#{pressed}']"))
        end

        def has_going_count?(count)
          has_css?(".event-invitees-icon .going", text: count.to_s)
        end

        def has_invitee_avatar?(username)
          has_css?(".event-invitees-avatars [data-user-card='#{username}']")
        end

        def has_hosts?(hosts, cohosted: false)
          host_label = cohosted ? "co_hosted_by" : "hosted_by"

          has_css?(".event-hosts", text: I18n.t("js.discourse_post_event.#{host_label}")) &&
            hosts.all? { |host| has_host?(host) }
        end

        # Hosts collapse into a menu once their row would wrap, so a host may
        # only be visible after opening it. Only positive waits are used here,
        # since CI fails a spec that lets a negative check run out its wait.
        def has_host?(host)
          name = host.name.presence || host.username
          inline = ".event-host [data-user-card='#{host.username}']"

          return false unless has_css?("#{inline}, .event-hosts__toggle")
          return true if has_css?(inline, text: name, wait: 0)

          find(".event-hosts__toggle").click unless has_css?(".event-hosts-menu", wait: 0)
          has_css?(".event-hosts-menu__host[data-user-card='#{host.username}']", text: name)
        end

        def has_creator_host?(user)
          has_css?(".created-by", text: I18n.t("js.discourse_post_event.created_and_hosted_by")) &&
            has_css?(".event-creator [data-user-card='#{user.username}']") &&
            has_no_css?(".event-hosts")
        end

        def has_no_invitee_avatar?(username)
          has_no_css?(".event-invitees-avatars [data-user-card='#{username}']")
        end

        def close_popup
          locator(".discourse-post-event-close").click
          has_no_css?("[data-identifier='post-event-menu']")
          self
        end

        def open_going_menu
          locator(".discourse-post-event-going-menu-trigger").click
          has_css?(".discourse-post-event-going-menu-content")
          self
        end

        def going_this_event
          open_going_menu
          locator(".discourse-post-event-going-menu-content .going-once").click
          self
        end

        def going_all_following
          open_going_menu
          locator(".discourse-post-event-going-menu-content .going-all").click
          self
        end

        def open_bulk_invite_modal
          open_more_menu { locator(".dropdown-menu__item.bulk-invite").click }
          self
        end

        def has_title_link_href?(href)
          has_css?(".event-info .name a[href='#{href}']")
        end

        def open_invite_user_or_group_modal
          open_more_menu { locator(".dropdown-menu__item.invite-user-or-group").click }
          self
        end

        def has_location?(text)
          has_css?(".event-location", text:)
        end

        def has_description?(text)
          has_css?(".event-description", text:)
        end

        def has_no_description?
          has_no_css?(".event-description")
        end

        def has_description_toggle?
          has_css?(".event-description__toggle")
        end

        def has_no_description_toggle?
          has_no_css?(".event-description__toggle")
        end

        def click_description_toggle
          locator(".event-description__toggle").click
          self
        end

        def has_description_clamped?
          has_css?(".event-description.is-clamped:not(.is-expanded)")
        end

        def has_description_expanded?
          has_css?(".event-description.is-clamped.is-expanded")
        end

        def close
          has_css?(".discourse-post-event .status-and-creators .status:not(.closed)")
          open_more_menu { locator(".close-event").click }
          locator("#dialog-holder .btn-primary").click
          has_css?(".discourse-post-event .status-and-creators .status.closed")
          has_no_css?("#{TRIGGER_MENU_SELECTOR}.--saving")
          self
        end

        def open
          has_css?(".discourse-post-event .status-and-creators .status.closed")
          open_more_menu { locator(".open-event").click }
          locator("#dialog-holder .btn-primary").click
          has_css?(".discourse-post-event .status-and-creators .status:not(.closed)")
          has_no_css?("#{TRIGGER_MENU_SELECTOR}.--saving")
          self
        end

        def add_to_calendar
          open_more_menu { locator(".add-to-calendar .btn").click }
          self
        end

        def edit
          open_more_menu { locator(".edit-event").click }
        end

        private

        def status_button_selector(status, state)
          button = ".event-status #{STATUS_BUTTONS.fetch(status)}"
          "#{button}#{state}, #{button} #{state}"
        end
      end
    end
  end
end
