// @ts-check
import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { block } from "discourse/blocks";
import { i18n } from "discourse-i18n";
/** @type {import("discourse/plugins/discourse-calendar/discourse/components/upcoming-events-list-view.gjs")} */
import UpcomingEventsListView from "../components/upcoming-events-list-view";
import {
  fetchUpcomingEvents,
  upcomingEventsListTitle,
} from "../lib/upcoming-events";

/**
 * Block registration for the calendar plugin's upcoming events
 * widget. Wraps `UpcomingEventsList` (the compact sidebar variant
 * used in themes like discourse-right-sidebar-blocks) so authors can
 * drop an events list into any block-driven outlet.
 *
 * The wrapped component reads `params.categoryId` to optionally pin
 * the list to a specific category — when blank, all categories are
 * included.
 */
@block("calendar:upcoming-events", {
  displayName: "Upcoming events",
  icon: "calendar-days",
  category: "Discourse data",
  description: "Compact sidebar list of upcoming calendar events.",
  args: {
    count: {
      type: "number",
      default: 8,
      integer: true,
      min: 1,
      max: 20,
      ui: {
        control: "number",
        label: i18n("discourse_post_event.upcoming_events_list.block.count"),
      },
    },
    upcomingDays: {
      type: "number",
      default: 180,
      integer: true,
      min: 1,
      max: 365,
      ui: {
        control: "number",
        label: i18n(
          "discourse_post_event.upcoming_events_list.block.upcoming_days"
        ),
        helpText: i18n(
          "discourse_post_event.upcoming_events_list.block.upcoming_days_help"
        ),
      },
    },
    categoryId: {
      type: "number",
      ui: {
        control: "category-select",
        label: i18n(
          "discourse_post_event.upcoming_events_list.block.category_id"
        ),
      },
    },
    includeSubcategories: {
      type: "boolean",
      default: false,
      ui: {
        control: "toggle",
        label: i18n(
          "discourse_post_event.upcoming_events_list.block.include_subcategories"
        ),
      },
    },
    timeFormat: {
      type: "string",
      default: "LT",
      ui: {
        label: i18n(
          "discourse_post_event.upcoming_events_list.block.time_format"
        ),
        helpText: i18n(
          "discourse_post_event.upcoming_events_list.block.time_format_help"
        ),
      },
    },
  },
  previewArgs: { count: 8, upcomingDays: 180 },
  data: {
    request: (args) => ({
      kind: "upcoming-events",
      count: args.count ?? 8,
      upcomingDays: args.upcomingDays ?? 180,
      categoryId: args.categoryId,
      includeSubcategories: args.includeSubcategories ?? false,
    }),
    resolve: (descriptor) => fetchUpcomingEvents(descriptor),
    skeleton: (args) => ({ variant: "rect", count: args.count ?? 8 }),
  },
})
export default class UpcomingEventsBlock extends Component {
  @service router;
  @service siteSettings;

  /**
   * The heading text, honouring the `map_events_title` per-category setting.
   * Rendered as chrome so it stays visible while the list loads.
   *
   * @returns {string}
   */
  get title() {
    return upcomingEventsListTitle({
      router: this.router,
      siteSettings: this.siteSettings,
    });
  }

  <template>
    <div class="upcoming-events-block">
      <div class="upcoming-events-list">
        {{! Chrome: the heading and the view-all footer render from args /
            settings, so they stay visible while the events load. Only the list
            inside the boundary shows the reserved-space skeleton. }}
        <h3 class="upcoming-events-list__heading">{{this.title}}</h3>

        <div class="upcoming-events-list__container">
          {{! The reserved-space skeleton comes from the block's `skeleton`
              hint (BlockData's default :loading); no :loading block needed. }}
          <@Data>
            <:content as |eventsByMonth|>
              <UpcomingEventsListView
                @eventsByMonth={{eventsByMonth}}
                @timeFormat={{@timeFormat}}
              />
            </:content>
            <:empty>
              <div class="upcoming-events-list__empty-message">
                {{i18n "discourse_post_event.upcoming_events_list.empty"}}
              </div>
            </:empty>
          </@Data>
        </div>

        <div class="upcoming-events-list__footer">
          <LinkTo
            @route="discourse-post-event-upcoming-events"
            class="upcoming-events-list__view-all"
          >
            {{i18n "discourse_post_event.upcoming_events_list.view_all"}}
          </LinkTo>
        </div>
      </div>
    </div>
  </template>
}
