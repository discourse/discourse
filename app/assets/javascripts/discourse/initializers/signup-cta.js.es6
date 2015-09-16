import ScreenTrack from 'discourse/lib/screen-track';
import Session from 'discourse/models/session';

const ANON_TOPIC_IDS = 3,
  ANON_PROMPT_READ_TIME = 5 * 60 * 1000,
  ONE_DAY = 24 * 60 * 60 * 1000,
  PROMPT_HIDE_DURATION = ONE_DAY;

export default {
  name: "signup-cta",

  initialize(container) {
    const screenTrack = ScreenTrack.current(),
      session = Session.current(),
      siteSettings = container.lookup('site-settings:main'),
      keyValueStore = container.lookup('key-value-store:main'),
      user = container.lookup('current-user:main');

    screenTrack.set('keyValueStore', keyValueStore);

    // Preconditions

    if (user) return; // must not be logged in
    if (keyValueStore.get('anon-cta-never')) return; // "never show again"
    if (!siteSettings.allow_new_registrations) return;
    if (siteSettings.invite_only) return;
    if (siteSettings.must_approve_users) return;
    if (siteSettings.login_required) return;
    if (!siteSettings.enable_signup_cta)  return;

    function checkSignupCtaRequirements() {
      if (session.get('showSignupCta')) {
        return; // already shown
      }

      if (session.get('hideSignupCta')) {
        return; // hidden for session
      }

      if (keyValueStore.get('anon-cta-never')) {
        return; // hidden forever
      }

      const now = new Date().getTime();
      const hiddenAt = keyValueStore.getInt('anon-cta-hidden', 0);
      if (hiddenAt > (now - PROMPT_HIDE_DURATION)) {
        return; // hidden in last 24 hours
      }

      const readTime = keyValueStore.getInt('anon-topic-time');
      if (readTime < ANON_PROMPT_READ_TIME) {
        return;
      }

      const topicIdsString = keyValueStore.get('anon-topic-ids');
      if (!topicIdsString) { return; }
      let topicIdsAry = topicIdsString.split(',');
      if (topicIdsAry.length < ANON_TOPIC_IDS) {
        return;
      }

      // Requirements met.
      session.set('showSignupCta', true);
    }

    screenTrack.set('anonFlushCallback', checkSignupCtaRequirements);

    checkSignupCtaRequirements();
  }
};
