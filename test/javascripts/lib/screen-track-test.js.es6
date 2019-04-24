import TopicTrackingState from "discourse/models/topic-tracking-state";
import Session from "discourse/models/session";
import ScreenTrack from "discourse/lib/screen-track";

let clock;

QUnit.module("lib:screen-track", {
  beforeEach() {
    clock = sinon.useFakeTimers(new Date(2012, 11, 31, 12, 0).getTime());
  },

  afterEach() {
    clock.restore();
  }
});

// skip for now test leaks state
QUnit.skip("Correctly flushes posts as needed", assert => {
  const timings = [];

  // prettier-ignore
  server.post("/topics/timings", t => { //eslint-disable-line
    timings.push(t);
    return [200, {}, ""];
  });

  const trackingState = TopicTrackingState.create();
  const siteSettings = {
    flush_timings_secs: 60
  };

  const currentUser = { id: 1, username: "sam" };

  const tracker = new ScreenTrack(
    trackingState,
    siteSettings,
    Session.current(),
    currentUser
  );

  const topicController = null;

  Discourse.set("hasFocus", true);

  tracker.reset();
  tracker.start(1, topicController);

  tracker.setOnscreen([1, 2, 3], [1, 2, 3]);

  clock.tick(1050);
  clock.tick(1050);

  // no ajax yet
  assert.equal(0, timings.length);

  tracker.setOnscreen([1, 2, 3, 4], [1, 2, 3]);

  clock.tick(1050);
  clock.tick(1050);

  // we should be rushed now cause there is a new thing on the screen
  assert.equal(1, timings.length);

  const req =
    "timings%5B1%5D=3000&timings%5B2%5D=3000&timings%5B3%5D=3000&timings%5B4%5D=1000&topic_time=3000&topic_id=1";
  assert.equal(timings[0].requestBody, req);

  tracker.stop();

  assert.equal(2, timings.length);

  const req2 =
    "timings%5B1%5D=1200&timings%5B2%5D=1200&timings%5B3%5D=1200&timings%5B4%5D=1200&topic_time=1200&topic_id=1";

  assert.equal(timings[1].requestBody, req2);
});
