import GlimmerComponent from "discourse/components/glimmer";
import { bind } from "discourse-common/utils/decorators";
createWidget("timeline-scrollarea", {
  tagName: "div.timeline-scrollarea",
  buildKey: (attrs) => `timeline-scrollarea-${attrs.topic.id}`,

  buildAttributes() {
    return { style: `height: ${scrollareaHeight()}px` };
  },

  defaultState(attrs) {
    return {
      percentage: this._percentFor(attrs.topic, attrs.enteredIndex + 1),
      scrolledPost: 1,
    };
  },

  position() {
    const { attrs } = this;
    const percentage = this.state.percentage;
    const topic = attrs.topic;
    const postStream = topic.get("postStream");
    const total = postStream.get("filteredPostsCount");

    const scrollPosition = clamp(Math.floor(total * percentage), 0, total) + 1;
    const current = clamp(scrollPosition, 1, total);

    const daysAgo = postStream.closestDaysAgoFor(current);
    let date;

    if (daysAgo === undefined) {
      const post = postStream
        .get("posts")
        .findBy("id", postStream.get("stream")[current]);

      if (post) {
        date = new Date(post.get("created_at"));
      }
    } else if (daysAgo !== null) {
      date = new Date();
      date.setDate(date.getDate() - daysAgo || 0);
    } else {
      date = null;
    }

    const result = {
      current,
      scrollPosition,
      total,
      date,
      lastRead: null,
      lastReadPercentage: null,
    };

    const lastReadId = topic.last_read_post_id;
    const lastReadNumber = topic.last_read_post_number;

    if (lastReadId && lastReadNumber) {
      const idx = postStream.get("stream").indexOf(lastReadId) + 1;
      result.lastRead = idx;
      result.lastReadPercentage = this._percentFor(topic, idx);
    }

    if (this.state.position !== result.scrollPosition) {
      this.state.position = result.scrollPosition;
      this.sendWidgetAction("updatePosition", current);
    }

    return result;
  },

  html(attrs, state) {
    const position = this.position();

    state.scrolledPost = position.current;
    const percentage = state.percentage;
    if (percentage === null) {
      return;
    }

    const before = scrollareaRemaining() * percentage;
    const after = scrollareaHeight() - before - SCROLLER_HEIGHT;

    let showButton = false;
    const hasBackPosition =
      position.lastRead &&
      position.lastRead > 3 &&
      position.lastRead > position.current &&
      Math.abs(position.lastRead - position.current) > 3 &&
      Math.abs(position.lastRead - position.total) > 1 &&
      position.lastRead !== position.total;

    if (hasBackPosition) {
      const lastReadTop = Math.round(
        position.lastReadPercentage * scrollareaHeight()
      );
      showButton =
        before + SCROLLER_HEIGHT - 5 < lastReadTop || before > lastReadTop + 25;
    }

    let scrollerAttrs = position;
    scrollerAttrs.showDockedButton =
      !attrs.mobileView && hasBackPosition && !showButton;
    scrollerAttrs.fullScreen = attrs.fullScreen;
    scrollerAttrs.topicId = attrs.topic.id;

    const result = [
      this.attach("timeline-padding", { height: before }),
      this.attach("timeline-scroller", scrollerAttrs),
      this.attach("timeline-padding", { height: after }),
    ];

    if (hasBackPosition) {
      const lastReadTop = Math.round(
        position.lastReadPercentage * scrollareaHeight()
      );
      result.push(
        this.attach("timeline-last-read", {
          top: lastReadTop,
          lastRead: position.lastRead,
          showButton,
        })
      );
    }

    return result;
  },

  updatePercentage(y) {
    const $area = $(".timeline-scrollarea");
    const areaTop = $area.offset().top;

    const percentage = clamp(parseFloat(y - areaTop) / $area.height());

    this.state.percentage = percentage;
  },

  commit() {
    const position = this.position();
    this.state.scrolledPost = position.current;

    if (position.current === position.scrollPosition) {
      this.sendWidgetAction("jumpToIndex", position.current);
    } else {
      this.sendWidgetAction("jumpEnd");
    }
  },

  topicCurrentPostScrolled(event) {
    this.state.percentage = event.percent;
  },

  _percentFor(topic, postIndex) {
    const total = topic.get("postStream.filteredPostsCount");
    return clamp(parseFloat(postIndex - 1.0) / total);
  },

  goBack() {
    this.sendWidgetAction("jumpToIndex", this.position().lastRead);
  },
});
