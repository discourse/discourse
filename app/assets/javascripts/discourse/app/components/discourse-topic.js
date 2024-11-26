import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import { getOwner } from "@ember/owner";
import { schedule, scheduleOnce } from "@ember/runloop";
import { isBlank } from "@ember/utils";
import { classNameBindings } from "@ember-decorators/component";
import { observes } from "@ember-decorators/object";
import $ from "jquery";
import ClickTrack from "discourse/lib/click-track";
import { highlightPost } from "discourse/lib/utilities";
import Scrolling from "discourse/mixins/scrolling";
import { bind } from "discourse-common/utils/decorators";

@classNameBindings(
  "multiSelect",
  "topic.archetype",
  "topic.is_warning",
  "topic.category.read_restricted:read_restricted",
  "topic.deleted:deleted-topic"
)
export default class DiscourseTopic extends Component.extend(Scrolling) {
  @alias("topic.userFilters") userFilters;
  @alias("topic.postStream") postStream;

  menuVisible = true;
  SHORT_POST = 1200;
  dockAt = 0;

  init() {
    super.init(...arguments);
    this.appEvents.on("discourse:focus-changed", this, "gotFocus");
    this.appEvents.on("post:highlight", this, "_highlightPost");
  }

  willDestroy() {
    super.willDestroy(...arguments);

    // this happens after route exit, stuff could have trickled in
    this.appEvents.off("discourse:focus-changed", this, "gotFocus");
    this.appEvents.off("post:highlight", this, "_highlightPost");
  }

  @observes("enteredAt")
  _enteredTopic() {
    // Ember is supposed to only call observers when values change but something
    // in our view set up is firing this observer with the same value. This check
    // prevents scrolled from being called twice
    if (this.enteredAt && this.lastEnteredAt !== this.enteredAt) {
      schedule("afterRender", this.scrolled);
      this.set("lastEnteredAt", this.enteredAt);
    }
  }

  _highlightPost(postNumber, options = {}) {
    if (isBlank(options.jump) || options.jump !== false) {
      scheduleOnce("afterRender", null, highlightPost, postNumber);
    }
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    this.bindScrolling();
    window.addEventListener("resize", this.scrolled);
    $(this.element).on(
      "click.discourse-redirect",
      ".cooked a, a.track-link",
      (e) => ClickTrack.trackClick(e, getOwner(this))
    );
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    this.unbindScrolling();
    window.removeEventListener("resize", this.scrolled);

    // Unbind link tracking
    $(this.element).off("click.discourse-redirect", ".cooked a, a.track-link");
  }

  gotFocus(hasFocus) {
    if (hasFocus) {
      this.scrolled();
    }
  }

  // The user has scrolled the window, or it is finished rendering and ready for processing.
  @bind
  scrolled() {
    if (this.isDestroyed || this.isDestroying || this._state !== "inDOM") {
      return;
    }

    const offset = window.pageYOffset || document.documentElement.scrollTop;
    this.set("hasScrolled", offset > 0);

    // Trigger a scrolled event
    this.appEvents.trigger("topic:scrolled", offset);
  }
}
