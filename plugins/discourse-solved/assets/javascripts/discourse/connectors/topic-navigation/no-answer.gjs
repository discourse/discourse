/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { later } from "@ember/runloop";
import { classNames, tagName } from "@ember-decorators/component";
import TopicNavigationPopup from "discourse/components/topic-navigation-popup";
import { isTesting } from "discourse/lib/environment";
import { i18n } from "discourse-i18n";

const ONE_WEEK = 7 * 24 * 60 * 60 * 1000; // milliseconds
const MAX_DURATION_WITH_NO_ANSWER = ONE_WEEK;
const DISPLAY_DELAY = isTesting() ? 0 : 2000;
const CONFETTI_PARTICLE_COUNT = 50;

@tagName("div")
@classNames("topic-navigation-outlet", "no-answer")
export default class NoAnswer extends Component {
  static shouldRender(args, context) {
    return !context.site.mobileView;
  }

  init() {
    super.init(...arguments);
    this.setProperties({
      oneWeek: ONE_WEEK,
      show: false,
      showConfetti: false,
    });

    this.appEvents.on(
      "discourse-solved:solution-toggled",
      this,
      this.hidePopup
    );

    later(() => {
      if (!this.element || this.isDestroying || this.isDestroyed) {
        return;
      }
      const topic = this.topic;
      const currentUser = this.currentUser;

      // show notice if:
      // - user can accept answer
      // - it does not have an accepted answer
      // - topic is old
      // - topic has at least one reply from another user that can be accepted
      if (
        !topic.accepted_answer &&
        currentUser &&
        topic.user_id === currentUser.id &&
        moment() - moment(topic.created_at) > MAX_DURATION_WITH_NO_ANSWER &&
        topic.postStream.posts.some(
          (post) => post.user_id !== currentUser.id && post.can_accept_answer
        )
      ) {
        this.set("show", true);
      }
    }, DISPLAY_DELAY);
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    this.appEvents.off(
      "discourse-solved:solution-toggled",
      this,
      this.hidePopup
    );
  }

  hidePopup() {
    if (!this.show) {
      return;
    }

    this.set("show", false);

    if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.set("showConfetti", true);
    }
  }

  get confettiParticles() {
    return Array.from({ length: CONFETTI_PARTICLE_COUNT }, (_, i) => i);
  }

  <template>
    {{#if this.showConfetti}}
      <div class="solved-confetti">
        {{#each this.confettiParticles}}
          <div class="solved-confetti-particle"></div>
        {{/each}}
      </div>
    {{/if}}
    {{#if this.show}}
      <TopicNavigationPopup
        @popupId="solved-notice"
        @dismissDuration={{this.oneWeek}}
      >
        <h2>{{i18n "solved.no_answer.title"}}</h2>
        <p>{{i18n "solved.no_answer.description"}}</p>
      </TopicNavigationPopup>
    {{/if}}
  </template>
}
