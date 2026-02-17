import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import TopicNavigationPopup from "discourse/components/topic-navigation-popup";
import { isTesting } from "discourse/lib/environment";
import discourseLater from "discourse/lib/later";
import { i18n } from "discourse-i18n";

const ONE_WEEK = 7 * 24 * 60 * 60 * 1000; // milliseconds
const MAX_DURATION_WITH_NO_ANSWER = ONE_WEEK;
const DISPLAY_DELAY = isTesting() ? 0 : 2000;
const CONFETTI_PARTICLE_COUNT = 50;

export default class NoAnswer extends Component {
  static shouldRender(args, context) {
    return !context.site.mobileView;
  }

  @service appEvents;
  @service currentUser;

  @tracked show = false;
  @tracked showConfetti = false;

  oneWeek = ONE_WEEK;

  constructor() {
    super(...arguments);

    this.appEvents.on(
      "discourse-solved:solution-toggled",
      this,
      this.hidePopup
    );

    discourseLater(() => {
      if (this.isDestroying) {
        return;
      }
      const topic = this.args.outletArgs.topic;
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
        this.show = true;
      }
    }, DISPLAY_DELAY);
  }

  willDestroy() {
    super.willDestroy(...arguments);

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

    this.show = false;

    if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.showConfetti = true;
    }
  }

  get confettiParticles() {
    return Array.from({ length: CONFETTI_PARTICLE_COUNT }, (_, i) => i);
  }

  <template>
    <div class="topic-navigation-outlet no-answer" ...attributes>
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
    </div>
  </template>
}
