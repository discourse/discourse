import GlimmerComponent from "discourse/components/glimmer";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";
import discourseLater from "discourse-common/lib/later";
import { action } from "@ember/object";
import { relativeAge } from "discourse/lib/formatter";
import I18n from "I18n";
import { htmlSafe } from "@ember/template";

export const SCROLLER_HEIGHT = 50;
const MIN_SCROLLAREA_HEIGHT = 170;
const MAX_SCROLLAREA_HEIGHT = 300;
const LAST_READ_HEIGHT = 20;

export default class TopicTimelineScrollArea extends GlimmerComponent {
  @tracked showButton = false;
  @tracked scrollPosition;
  @tracked current;
  @tracked percentage = this.scrollPercentage;
  @tracked total;
  @tracked date;
  @tracked lastReadPercentage = null;
  @tracked position;
  @tracked displayTimeLineScrollArea = true;

  get style() {
    return htmlSafe(`height: ${scrollareaHeight()}px`);
  }
  get after() {
    return scrollareaHeight() - this.before - SCROLLER_HEIGHT;
  }

  get showDockedButton() {
    return !this.site.mobileView && this.hasBackPosition && !this.showButton;
  }

  get hasBackPosition() {
    return (
      this.lastRead &&
      this.lastRead > 3 &&
      this.lastRead > this.current &&
      Math.abs(this.lastRead - this.current) > 3 &&
      Math.abs(this.lastRead - this.total) > 1 &&
      this.lastRead !== this.total
    );
  }

  get beforePadding() {
    return htmlSafe(`height: ${this.before}px`);
  }

  get afterPadding() {
    return htmlSafe(`height: ${this.after}px`);
  }

  get lastReadStyle() {
    return htmlSafe(
      `height: ${LAST_READ_HEIGHT}px; top: ${this.topPosition}px`
    );
  }

  get topPosition() {
    const bottom = scrollareaHeight() - LAST_READ_HEIGHT / 2;
    return this.lastReadTop > bottom ? bottom : this.lastReadTop;
  }

  get bottomAge() {
    return relativeAge(
      new Date(this.args.topic.last_posted_at || this.args.topic.created_at),
      {
        addAgo: true,
        defaultFormat: timelineDate,
      }
    );
  }

  get startDate() {
    return timelineDate(this.args.topic.createdAt);
  }

  get nowDate() {
    return this.bottomAge;
  }

  get scrollPercentage() {
    return this._percentFor(this.args.topic, this.args.enteredIndex + 1);
  }

  get lastReadHeight() {
    return Math.round(this.lastReadPercentage * scrollareaHeight());
  }

  constructor() {
    super(...arguments);

    if (!this.site.mobileView) {
      const streamLength = this.args.topic.get("postStream.stream.length");

      if (streamLength === 1) {
        const postsWrapper = document.querySelector(".posts-wrapper");
        if (postsWrapper && postsWrapper.offsetHeight < 1000) {
          this.displayTimeLineScrollArea = false;
        }
      }
    }

    this.calculatePosition();
    if (this.percentage === null) {
      return;
    }

    this.before = this.scrollareaRemaining() * this.percentage;

    if (this.hasBackPosition) {
      this.lastReadTop = Math.round(
        this.lastReadPercentage * scrollareaHeight()
      );
      this.showButton =
        this.before + SCROLLER_HEIGHT - 5 < this.lastReadTop ||
        this.before > this.lastReadTop + 25;
    }

    if (this.hasBackPosition) {
      this.lastReadTop = Math.round(
        this.lastReadPercentage * scrollareaHeight()
      );
    }
  }

  @action
  goBack() {
    this.args.jumpToIndex(this.lastRead);
  }

  @action
  updatePercentage(e) {
    const y = e.pageY;
    const $area = $(".timeline-scrollarea");
    const areaTop = $area.offset().top;

    const percentage = this.clamp(parseFloat(y - areaTop) / $area.height());
    this.percentage = percentage;
    this.commit();
  }

  calculatePosition() {
    const topic = this.args.topic;
    const postStream = topic.get("postStream");
    this.total = postStream.get("filteredPostsCount");

    this.scrollPosition = this.clamp(
      Math.floor(this.total * this.percentage),
      0,
      this.total
    );
    this.current = this.clamp(this.scrollPosition, 1, this.total);
    const daysAgo = postStream.closestDaysAgoFor(this.current);

    let date;
    if (daysAgo === undefined) {
      const post = postStream
        .get("posts")
        .findBy("id", postStream.get("stream")[this.current]);

      if (post) {
        date = new Date(post.get("created_at"));
      }
    } else if (daysAgo !== null) {
      date = new Date();
      date.setDate(date.getDate() - daysAgo || 0);
    } else {
      date = null;
    }

    this.date = date;

    const lastReadId = topic.last_read_post_id;
    const lastReadNumber = topic.last_read_post_number;

    if (lastReadId && lastReadNumber) {
      const idx = postStream.get("stream").indexOf(lastReadId) + 1;
      this.lastRead = idx;
      this.lastReadPercentage = this._percentFor(topic, idx);
    }

    if (this.position !== this.scrollPosition) {
      this.position = this.scrollPosition;
      console.log(this.position);
      this.updateScrollPosition(this.current);
    }
  }

  updateScrollPosition(scrollPosition) {
    // only ran on mobile
    if (!this.args.fullscreen) {
      return;
    }

    this.position = scrollPosition;
    this.excerpt = "";

    //const stream = this.args.topic.get("postStream");

    // a little debounce to avoid flashing
    discourseLater(() => {
      if (!this.position === scrollPosition) {
        return;
      }

      // we have an off by one, stream is zero based,
      // OLD WIDGET CODE
      //stream.excerpt(scrollPosition - 1).then((info) => {
      //if (info && this.position === scrollPosition) {
      //let excerpt = "";

      //if (info.username) {
      //excerpt = "<span class='username'>" + info.username + ":</span> ";
      //}

      //if (info.excerpt) {
      //this.excerpt = excerpt + info.excerpt;
      //} else if (info.action_code) {
      //this.state.excerpt = `${excerpt} ${actionDescriptionHtml(
      //info.action_code,
      //info.created_at,
      //info.username
      //)}`;
      //}

      //this.queueRerender();
      //}
      //});
    }, 50);
  }

  @bind
  commit() {
    const position = this.position();
    this.state.scrolledPost = position.current;

    if (position.current === position.scrollPosition) {
      this.sendWidgetAction("jumpToIndex", position.current);
    } else {
      this.sendWidgetAction("jumpEnd");
    }

    this.calculatePosition();

    if (this.current === this.scrollPosition) {
      this.args.jumpToIndex(this.current);
    } else {
      this.args.jumpEnd();
    }
  }

  @bind
  _percentFor(topic, postIndex) {
    const total = topic.get("postStream.filteredPostsCount");
    return this.clamp(parseFloat(postIndex - 1.0) / total);
  }

  @bind
  clamp(p, min = 0.0, max = 1.0) {
    return Math.max(Math.min(p, max), min);
  }

  @bind
  scrollareaRemaining() {
    return scrollareaHeight() - SCROLLER_HEIGHT;
  }
}

export function scrollareaHeight() {
  const composerHeight =
      document.getElementById("reply-control").offsetHeight || 0,
    headerHeight = document.querySelectorAll(".d-header")[0].offsetHeight || 0;

  // scrollarea takes up about half of the timeline's height
  const availableHeight =
    (window.innerHeight - composerHeight - headerHeight) / 2;

  return Math.max(
    MIN_SCROLLAREA_HEIGHT,
    Math.min(availableHeight, MAX_SCROLLAREA_HEIGHT)
  );
}

export function timelineDate(date) {
  const fmt =
    date.getFullYear() === new Date().getFullYear()
      ? "long_no_year_no_time"
      : "timeline_date";
  return moment(date).format(I18n.t(`dates.${fmt}`));
}
