import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { dependentKeyCompat } from "@ember/object/compat";
import { trackedMap } from "@ember/reactive/collections";
import Service, { service } from "@ember/service";
import deprecated from "discourse/lib/deprecated";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { SCROLLED_DOWN, SCROLLED_UP } from "./scroll-direction";

const VALID_HEADER_BUTTONS_TO_HIDE = ["search", "login", "signup", "menu"];

@disableImplicitInjections
export default class Header extends Service {
  @service scrollDirection;
  @service site;

  @tracked headerOffset = 0;
  @tracked mainOutletOffset = 0;

  /**
   * The topic currently viewed on the page.
   *
   * The information is updated as soon as the page is loaded.
   *
   * @type {Topic|null}
   */
  @tracked topicInfo = null;

  @tracked hamburgerVisible = false;
  @tracked userVisible = false;
  #hiders = trackedMap();
  @tracked _mainTopicTitleVisible = false;

  // Latch: when the title scrolls out of view while scrolling down,
  // hold the "show topic info" decision even if the IntersectionObserver
  // briefly reports the title as visible again. This prevents a feedback
  // loop when themes/plugins use a dynamic header height: showing the
  // topic info grows the sticky header, shifting content, which pushes
  // the title back into the observer viewport, which hides the topic
  // info, which shrinks the header — hundreds of times per second.
  @tracked _topicInfoLatched = false;

  get mainTopicTitleVisible() {
    return this._mainTopicTitleVisible;
  }

  set mainTopicTitleVisible(value) {
    this._mainTopicTitleVisible = value;

    if (!value) {
      this._topicInfoLatched = true;
    } else if (this.scrollDirection.lastScrollDirection === SCROLLED_UP) {
      this._topicInfoLatched = false;
    }
  }

  get topic() {
    deprecated(
      "`.topic` is deprecated in service:header. Use `.topicInfo` or `.topicInfoVisible` instead.",
      {
        id: "discourse.header-service-topic",
        since: "3.3.0.beta4-dev",
      }
    );

    return this.topicInfoVisible ? this.topicInfo : null;
  }

  /**
   * Indicates whether topic info should be displayed
   * in the header.
   */
  @dependentKeyCompat // For legacy `site-header` observer compat
  get topicInfoVisible() {
    if (!this.topicInfo) {
      return false;
    }

    // The latch is only honored while actively scrolling down — this
    // prevents the IntersectionObserver feedback loop (header height
    // change shifting content), but automatically releases when scroll
    // direction changes so topic info hides normally.
    const isLatched =
      this._topicInfoLatched &&
      this.scrollDirection.lastScrollDirection === SCROLLED_DOWN;

    if (this.mainTopicTitleVisible && !isLatched) {
      return false;
    }

    if (
      this.site.mobileView &&
      this.scrollDirection.lastScrollDirection === SCROLLED_UP
    ) {
      return false;
    }

    return true;
  }

  registerHider(ref, buttons) {
    const validButtons = buttons
      .map((button) => {
        if (!VALID_HEADER_BUTTONS_TO_HIDE.includes(button)) {
          // eslint-disable-next-line no-console
          console.error(
            `Invalid button to hide: ${button}, valid buttons are: ${VALID_HEADER_BUTTONS_TO_HIDE.join(
              ","
            )}`
          );
        } else {
          return button;
        }
      })
      .filter(Boolean);

    if (!validButtons.length) {
      return;
    }

    this.#hiders.set(ref, validButtons);

    registerDestructor(ref, () => {
      this.#hiders.delete(ref);
    });
  }

  get headerButtonsHidden() {
    const buttonsToHide = new Set();
    this.#hiders.forEach((buttons) => {
      buttons.forEach((button) => {
        buttonsToHide.add(button);
      });
    });
    return Array.from(buttonsToHide);
  }

  /**
   * Called whenever a topic route is entered. Sets the current topicInfo,
   * and makes a guess about whether the main topic title is likely to be visible
   * on initial load. The IntersectionObserver will correct this later if needed.
   */
  enterTopic(topic, isLoadingFirstPost) {
    this.topicInfo = topic;
    this._topicInfoLatched = false;
    this.mainTopicTitleVisible = isLoadingFirstPost;
  }

  clearTopic() {
    this.topicInfo = null;
    this._topicInfoLatched = false;
    this.mainTopicTitleVisible = false;
  }
}
