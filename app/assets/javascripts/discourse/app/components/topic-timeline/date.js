import GlimmerComponent from "discourse/components/glimmer";
import { bind } from "discourse-common/utils/decorators";
import { relativeAge } from "discourse/lib/formatter";
import { tracked } from "@glimmer/tracking";

export default class TopicTimelineDate extends GlimmerComponent {
  @tracked displayTimeLineScrollArea = true;

  bottomAge = relativeAge(
    new Date(this.args.topic.last_posted_at || this.args.topic.created_at),
    {
      addAgo: true,
      defaultFormat: timelineDate,
    }
  );

  get label() {
    return this.args.class === "start-date"
      ? timelineDate(this.args.topic.createdAt)
      : this.bottomAge;
  }

  constructor() {
    super(...arguments);

    if (!this.site.mobileView) {
      const streamLength = this.args.topic.get("postStream.stream.length");

      if (streamLength === 1) {
        const postsWrapper = document.querySelector(".posts-wrapper");
        if (postsWrapper && postsWrapper.offsetHeight < 1000) {
          this.updateDisplayTimeLineScrollArea(false);
        }
      }
    }
  }

  @bind
  updateDisplayTimeLineScrollArea(arg) {
    this.displayTimeLineScrollArea = arg;
  }
}

export function timelineDate(date) {
  const fmt =
    date.getFullYear() === new Date().getFullYear()
      ? "long_no_year_no_time"
      : "timeline_date";
  return moment(date).format(I18n.t(`dates.${fmt}`));
}
