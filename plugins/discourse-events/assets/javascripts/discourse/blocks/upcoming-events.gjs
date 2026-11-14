// @ts-check
import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { block, defineBlockDataSource } from "discourse/blocks";
import BlockFrame, { frameArgs } from "discourse/blocks/block-frame";
import getURL from "discourse/lib/get-url";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
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
    title: {
      type: "string",
      ui: {
        label: i18n("discourse_post_event.upcoming_events_list.block.title"),
        helpText: i18n(
          "discourse_post_event.upcoming_events_list.block.title_help"
        ),
        placeholder: i18n("discourse_post_event.upcoming_events_list.title"),
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
    ...frameArgs({ defaultIcon: "calendar-days", withLink: true }),
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
    skeleton: (args) => ({ variant: "rect", count: args.count ?? 8 }),
  },
})
export default class UpcomingEventsBlock extends Component {
  @service router;
  @service siteSettings;

  /**
   * The heading text: the author's title, otherwise the default honouring the
   * `map_events_title` per-category setting.
   * Rendered as chrome so it stays visible while the list loads.
   *
   * @returns {string}
   */
  get title() {
    const title = this.args.title?.trim();
    if (title) {
      return title;
    }
    return upcomingEventsListTitle({
      router: this.router,
      siteSettings: this.siteSettings,
    });
  }

  get linkHref() {
    return this.args.linkHref || getURL("/upcoming-events");
  }

  get linkLabel() {
    return (
      this.args.linkLabel ||
      i18n("discourse_post_event.upcoming_events_list.view_all")
    );
  }

  <template>
    <BlockFrame
      @frameStyle={{@frameStyle}}
      @icon={{@icon}}
      @linkHref={{this.linkHref}}
      @linkLabel={{this.linkLabel}}
      @title={{this.title}}
      as |frame|
    >
      <div
        class={{dConcatClass
          "upcoming-events-block"
          (unless frame.isPlain "d-block-frame__content")
        }}
      >
        <div class="upcoming-events-list">
          {{! Chrome: the heading and the view-all footer render from args /
            settings, so they stay visible while the events load. Only the list
            inside the boundary shows the reserved-space skeleton. }}
          {{#if frame.isPlain}}
            <h3 class="upcoming-events-list__heading">{{this.title}}</h3>
          {{/if}}

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

          {{#if frame.isPlain}}
            <div class="upcoming-events-list__footer">
              <LinkTo
                class="upcoming-events-list__view-all"
                @route="discourse-post-event-upcoming-events"
              >
                {{i18n "discourse_post_event.upcoming_events_list.view_all"}}
              </LinkTo>
            </div>
          {{/if}}
        </div>
      </div>
    </BlockFrame>
  </template>
}
