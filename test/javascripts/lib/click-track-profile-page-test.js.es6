import DiscourseURL from "discourse/lib/url";
import ClickTrack from "discourse/lib/click-track";
import { fixture, logIn } from "helpers/qunit-helpers";

QUnit.module("lib:click-track-profile-page", {
  beforeEach() {
    logIn();

    let win = { focus: function() {} };
    sandbox.stub(window, "open").returns(win);
    sandbox.stub(win, "focus");

    sandbox.stub(DiscourseURL, "routeTo");
    sandbox.stub(DiscourseURL, "redirectTo");

    sessionStorage.clear();

    fixture().html(
      `<p class="excerpt first" data-post-id="42" data-topic-id="1337" data-user-id="3141">
        <a href="http://www.google.com">google.com</a>
        <a class="lightbox back" href="http://www.google.com">google.com</a>
        <div class="onebox-result">
          <a id="inside-onebox" href="http://www.google.com">google.com<span class="badge">1</span></a>
          <a id="inside-onebox-forced" class="track-link" href="http://www.google.com">google.com<span class="badge">1</span></a>
        </div>
        <a class="no-track-link" href="http://www.google.com">google.com</a>
        <a id="same-site" href="http://discuss.domain.com">forum</a>
        <a class="attachment" href="http://discuss.domain.com/uploads/default/1234/1532357280.txt">log.txt</a>
        <a class="hashtag" href="http://discuss.domain.com">#hashtag</a>
      </p>
      <p class="excerpt second" data-post-id="24" data-topic-id="7331" data-user-id="1413">
        <a href="http://www.google.com">google.com</a>
        <a class="lightbox back" href="http://www.google.com">google.com</a>
        <div class="onebox-result">
          <a id="inside-onebox" href="http://www.google.com">google.com<span class="badge">1</span></a>
          <a id="inside-onebox-forced" class="track-link" href="http://www.google.com">google.com<span class="badge">1</span></a>
        </div>
        <a class="no-track-link" href="http://www.google.com">google.com</a>
        <a id="same-site" href="http://discuss.domain.com">forum</a>
        <a class="attachment" href="http://discuss.domain.com/uploads/default/1234/1532357280.txt">log.txt</a>
        <a class="hashtag" href="http://discuss.domain.com">#hashtag</a>
      </p>`
    );
  }
});

var track = ClickTrack.trackClick;

function generateClickEventOn(selector) {
  return $.Event("click", { currentTarget: fixture(selector).first() });
}

QUnit.skip("tracks internal URLs", async assert => {
  assert.expect(2);
  sandbox.stub(DiscourseURL, "origin").returns("http://discuss.domain.com");

  const done = assert.async();
  /* global server */
  server.post("/clicks/track", request => {
    assert.equal(request.requestBody, "url=http%3A%2F%2Fdiscuss.domain.com");
    done();
  });

  assert.notOk(track(generateClickEventOn("#same-site")));
});

QUnit.skip("tracks external URLs", async assert => {
  assert.expect(2);

  const done = assert.async();
  /* global server */
  server.post("/clicks/track", request => {
    assert.equal(
      request.requestBody,
      "url=http%3A%2F%2Fwww.google.com&post_id=42&topic_id=1337"
    );
    done();
  });

  assert.notOk(track(generateClickEventOn("a")));
});

QUnit.skip("tracks external URLs in other posts", async assert => {
  assert.expect(2);

  const done = assert.async();
  /* global server */
  server.post("/clicks/track", request => {
    assert.equal(
      request.requestBody,
      "url=http%3A%2F%2Fwww.google.com&post_id=24&topic_id=7331"
    );
    done();
  });

  assert.notOk(track(generateClickEventOn(".second a")));
});
