import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AsyncContent from "discourse/components/async-content";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import Category from "discourse/models/category";
import Topic from "discourse/models/topic";
import { formatEventName } from "../helpers/format-event-name";
import { isNotFullDayEvent } from "../lib/guess-best-date-format";
import FullCalendar from "./full-calendar";

export default class CategoryCalendar extends Component {
  @service currentUser;
  @service router;
  @service siteSettings;
  @service store;
  @service discoursePostEventApi;

  @bind
  async loadEvents() {
    try {
      if (this.categorySettings?.postId) {
        const post = await this.store.find(
          "post",
          this.categorySettings.postId
        );
        const topic_json = await Topic.find(post.topic_id, {});
        const topic = Topic.create(topic_json);
        post.set("topic", topic);

        return (post?.calendar_details || []).map((detail) => {
          return {
            post,
            name: detail.message,
            startsAt: detail.from,
            endsAt: detail.to,
            categoryId: this.category.id,
          };
        });
      } else {
        const params = {
          post_id: this.categorySettings?.postId,
          category_id: this.category.id,
          include_subcategories: true,
        };

        if (this.siteSettings.include_expired_events_on_calendar) {
          params.include_expired = true;
        }

        return await this.discoursePostEventApi.events(params);
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  get tagsColorsMap() {
    return JSON.parse(this.siteSettings.map_events_to_color);
  }

  get shouldRender() {
    if (this.siteSettings.login_required && !this.currentUser) {
      return false;
    }

    if (!this.router.currentRoute?.params?.category_slug_path_with_id) {
      return false;
    }

    if (!this.category) {
      return false;
    }

    return true;
  }

  get category() {
    return Category.findBySlugPathWithID(
      this.router.currentRoute.params.category_slug_path_with_id
    );
  }

  get renderWeekends() {
    return this.categorySettings?.weekends !== "false";
  }

  get categorySettings() {
    const settings = this.siteSettings.calendar_categories
      .split("|")
      .filter(Boolean)
      .map((stringSetting) => {
        const data = {};
        stringSetting
          .split(";")
          .filter(Boolean)
          .forEach((s) => {
            const parts = s.split("=");
            data[parts[0]] = parts[1];
          });
        return data;
      });

    return settings.findBy("categoryId", this.category.id.toString());
  }

  @action
  formatedEvents(events = []) {
    return events.map((event) => {
      const { startsAt, endsAt, post, categoryId } = event;

      let backgroundColor;

      if (post.topic.tags) {
        const tagColorEntry = this.tagsColorsMap.find(
          (entry) =>
            entry.type === "tag" && post.topic.tags.includes(entry.slug)
        );
        backgroundColor = tagColorEntry ? tagColorEntry.color : null;
      }

      if (!backgroundColor) {
        const categoryColorFromMap = this.tagsColorsMap.find(
          (entry) =>
            entry.type === "category" && entry.slug === post.topic.category_slug
        )?.color;
        backgroundColor =
          categoryColorFromMap || `#${Category.findById(categoryId)?.color}`;
      }

      let classNames;
      if (moment(endsAt || startsAt).isBefore(moment())) {
        classNames = "fc-past-event";
      }

      return {
        title: formatEventName(event, this.currentUser?.user_option?.timezone),
        start: startsAt,
        rrule: event.rrule,
        end: endsAt || startsAt,
        allDay: !isNotFullDayEvent(moment(startsAt), moment(endsAt)),
        url: getURL(`/t/-/${post.topic.id}/${post.post_number}`),
        backgroundColor,
        classNames,
      };
    });
  }

  <template>
    {{#if this.shouldRender}}
      <AsyncContent @asyncData={{this.loadEvents}}>
        <:content as |events|>
          <FullCalendar
            @events={{this.formatedEvents events}}
            @height="650px"
            @initialView={{this.categorySettings?.defaultView}}
            @weekends={{this.renderWeekends}}
          />
        </:content>
      </AsyncContent>
    {{/if}}
  </template>
}
