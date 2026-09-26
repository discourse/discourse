import { lookup } from "discourse/lib/service";
import EmbedMode from "discourse/lib/embed-mode";
import Session from "discourse/models/session";
import AppEventsService from "discourse/services/app-events";
import CurrentUserService from "discourse/services/current-user";
import KeyValueStoreService from "discourse/services/key-value-store";
import ScreenTrackService from "discourse/services/screen-track";
import SiteSettingsService from "discourse/services/site-settings";

const ANON_TOPIC_IDS = 2;
const ANON_PROMPT_READ_TIME = 2 * 60 * 1000;
const ONE_DAY = 24 * 60 * 60 * 1000;
const PROMPT_HIDE_DURATION = ONE_DAY;

export default {
  initialize(owner) {
    const appEvents = lookup(owner, AppEventsService);
    const applicationController = owner.lookup("controller:application");
    const currentUser = lookup(owner, CurrentUserService);
    const keyValueStore = lookup(owner, KeyValueStoreService);
    const screenTrack = lookup(owner, ScreenTrackService);
    const session = Session.current();
    const { enable_signup_cta, login_required } = lookup(
      owner,
      SiteSettingsService
    );

    if (currentUser) {
      return;
    }
    if (!enable_signup_cta) {
      return;
    }
    if (login_required) {
      return;
    }
    if (EmbedMode.enabled) {
      return;
    }

    function checkSignupCtaRequirements() {
      if (!applicationController.canSignUp) {
        return; // signup is unavailable
      }

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
