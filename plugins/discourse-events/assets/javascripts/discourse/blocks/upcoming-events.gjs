// @ts-check
import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { block, defineBlockDataSource } from "discourse/blocks";
import BlockPanel from "discourse/blocks/block-panel";
import { i18n } from "discourse-i18n";
/** @type {import("discourse/plugins/discourse-events/discourse/components/upcoming-events-list-view.gjs")} */
import UpcomingEventsListView from "../components/upcoming-events-list-view";
import {
  fetchUpcomingEvents,
  upcomingEventsListTitle,
} from "../lib/upcoming-events";

const upcomingEventsDataSource = defineBlockDataSource({
  resolve: (descriptor) => fetchUpcomingEvents(descriptor),
});

/**
 * Block registration for the events plugin's upcoming events
 * widget. Wraps `UpcomingEventsList` (the compact sidebar variant
 * used in themes like discourse-right-sidebar-blocks) so authors can
 * drop an events list into any block-driven outlet.
 *
 * The wrapped component reads `params.categoryId` to optionally pin
 * the list to a specific category — when blank, all categories are
 * included.
 */
@block("events:upcoming-events", {
  displayName: "Upcoming events",
  icon: "calendar-days",
  category: "community",
  description: "Compact sidebar list of upcoming calendar events.",
  args: {
    icon: {
      type: "string",
      default: "",
      ui: {
        control: "icon",
        label: i18n("discourse_post_event.upcoming_events_list.block.icon"),
      },
    },
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
    source: upcomingEventsDataSource,
    request: (args) => ({
      kind: "upcoming-events",
      count: args.count ?? 8,
      upcomingDays: args.upcomingDays ?? 180,
      categoryId: args.categoryId,
      includeSubcategories: args.includeSubcategories ?? false,
    }),
    skeleton: (args) => ({ rows: "link", count: args.count ?? 8 }),
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
    <BlockPanel
      class="events-block-upcoming-events"
      @Data={{@Data}}
      @icon={{@icon}}
      @title={{this.title}}
    >
      <:content as |eventsByMonth|>
        <UpcomingEventsListView
          @eventsByMonth={{eventsByMonth}}
          @timeFormat={{@timeFormat}}
        />
      </:content>
      <:empty>
        <p class="d-block-panel__empty">
          {{i18n "discourse_post_event.upcoming_events_list.empty"}}
        </p>
      </:empty>
      <:footer>
        <LinkTo
          class="d-block-panel__link"
          @route="discourse-post-event-upcoming-events"
        >
          {{i18n "discourse_post_event.upcoming_events_list.view_all"}}
        </LinkTo>
      </:footer>
    </BlockPanel>
  </template>
}
