import DiscourseURL from "discourse/lib/url";
import ClickTrack from "discourse/lib/click-track";
import { logIn } from "helpers/qunit-helpers";

QUnit.module("lib:click-track-edit-history", {
  beforeEach() {
    logIn();

    let win = { focus: function() {} };
    sandbox.stub(window, "open").returns(win);
    sandbox.stub(win, "focus");

    sandbox.stub(DiscourseURL, "routeTo");
    sandbox.stub(DiscourseURL, "redirectTo");

    sessionStorage.clear();

    fixture().html(
      `<div id="topic" data-topic-id="1337">
       </div>
       <div id="revisions" data-post-id="42" class="">
         <div class="row">
           <div class="span8">
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
           </div>
           <div class="span8 offset1">
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
           </div>
         </div>
       </div>`
    );
  }
});

var track = ClickTrack.trackClick;

function generateClickEventOn(selector) {
  return $.Event("click", { currentTarget: fixture(selector).first() });
}

QUnit.test("tracks internal URLs", async assert => {
  assert.expect(2);
  sandbox.stub(DiscourseURL, "origin").returns("http://discuss.domain.com");

  const done = assert.async();
  /* global server */
  server.get("/clicks/track", request => {
    assert.ok(
      request.url.indexOf(
        "url=http%3A%2F%2Fdiscuss.domain.com&post_id=42&topic_id=1337"
      ) !== -1
    );
    done();
  });

  assert.notOk(track(generateClickEventOn("#same-site")));
});

QUnit.test("tracks external URLs", async assert => {
  assert.expect(2);

  const done = assert.async();
  /* global server */
  server.get("/clicks/track", request => {
    assert.ok(
      request.url.indexOf(
        "url=http%3A%2F%2Fwww.google.com&post_id=42&topic_id=1337"
      ) !== -1
    );
    done();
  });

  assert.notOk(track(generateClickEventOn("a")));
});

QUnit.test(
  "tracks external URLs when opening in another window",
  async assert => {
    assert.expect(3);
    Discourse.User.currentProp("external_links_in_new_tab", true);

    const done = assert.async();
    /* global server */
    server.get("/clicks/track", request => {
      assert.ok(
        request.url.indexOf(
          "url=http%3A%2F%2Fwww.google.com&post_id=42&topic_id=1337"
        ) !== -1
      );
      done();
    });

    assert.notOk(track(generateClickEventOn("a")));
    assert.ok(window.open.calledWith("http://www.google.com", "_blank"));
  }
);
