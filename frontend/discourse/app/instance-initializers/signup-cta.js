import Session from "discourse/models/session";

const ANON_TOPIC_IDS = 2;
const ANON_PROMPT_READ_TIME = 2 * 60 * 1000;
const ONE_DAY = 24 * 60 * 60 * 1000;
const PROMPT_HIDE_DURATION = ONE_DAY;

export default {
  initialize(owner) {
    const appEvents = owner.lookup("service:app-events");
    const { canSignUp } = owner.lookup("controller:application");
    const currentUser = owner.lookup("service:current-user");
    const keyValueStore = owner.lookup("service:key-value-store");
    const screenTrack = owner.lookup("service:screen-track");
    const session = Session.current();
    const { enable_signup_cta, login_required } = owner.lookup(
      "service:site-settings"
    );

    if (currentUser) {
      return;
    }
    if (!enable_signup_cta) {
      return;
    }
    if (!canSignUp) {
      return;
    }
    if (login_required) {
      return;
    }

    function checkSignupCtaRequirements() {
      if (session.get("showSignupCta")) {
        return; // already shown
      }

      if (session.get("hideSignupCta")) {
        return; // hidden for session
      }

      if (keyValueStore.get("anon-cta-never")) {
        return; // hidden forever
      }

      const hiddenAt = keyValueStore.getInt("anon-cta-hidden", 0);
      if (hiddenAt > Date.now() - PROMPT_HIDE_DURATION) {
        return; // hidden in last 24 hours
      }

      const readTime = keyValueStore.getInt("anon-topic-time");
      if (readTime < ANON_PROMPT_READ_TIME) {
        return;
      }

      const topicIds = keyValueStore.get("anon-topic-ids");
      if (!topicIds) {
        return;
      }

      if (topicIds.split(",").length < ANON_TOPIC_IDS) {
        return;
      }

      // Requirements met.
      session.set("showSignupCta", true);
      appEvents.trigger("cta:shown");
    }

    screenTrack.registerAnonCallback(checkSignupCtaRequirements);

    checkSignupCtaRequirements();
  },
};
