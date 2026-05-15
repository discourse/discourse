// @ts-check
import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { block } from "discourse/blocks";
import { i18n } from "discourse-i18n";
import UpcomingEventsList from "../components/upcoming-events-list";

/**
 * Visual-editor block for the calendar plugin's upcoming events
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
})
export default class UpcomingEventsBlock extends Component {
  <template>
    <div class="upcoming-events-block">
      <UpcomingEventsList
        @params={{hash
          count=@count
          upcomingDays=@upcomingDays
          categoryId=@categoryId
          includeSubcategories=@includeSubcategories
          timeFormat=@timeFormat
        }}
      />
    </div>
  </template>
}
