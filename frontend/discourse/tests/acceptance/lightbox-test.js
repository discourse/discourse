import { click, visit, waitFor, waitUntil } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Lightbox", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    const topicResponse = cloneJSON(topicFixtures["/t/280/1.json"]);
    topicResponse.post_stream.posts[0].cooked += `<div class="lightbox-wrapper">
      <a class="lightbox" href="/images/d-logo-sketch.png" data-download-href="//discourse.local/uploads/default/ad768537789cdf4679a18161ac0b0b6f0f4ccf9e" title="<script>image</script>">
        <img src="/images/d-logo-sketch-small.png" alt="<script>image</script>" data-base62-sha1="oKwwVE8qLWFBkE5UJeCs2EwxHHg" width="690" height="387" srcset="/images/d-logo-sketch-small.png" data-small-upload="/images/d-logo-sketch-small.png">
        <div class="meta">
          <svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg>
          <span class="filename">image</span><span class="informations">1500×842 234 KB</span>
          <svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg>
        </div>
      </a>
    </div>`;

    server.get("/t/280.json", () => helper.response(topicResponse));
    server.get("/t/280/:post_number.json", () =>
      helper.response(topicResponse)
    );
  });

  test("Shows 'download' and 'original image' buttons", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".lightbox");

    await waitFor(".pswp--open");

    assert
      .dom(".pswp__caption .pswp__caption-title")
      .hasText("<script>image</script>");
    assert
      .dom(".pswp__caption .pswp__caption-details")
      .hasText("1500×842 234 KB");

    assert
      .dom(".pswp__button--download-image")
      .hasAttribute(
        "href",
        "//discourse.local/uploads/default/ad768537789cdf4679a18161ac0b0b6f0f4ccf9e"
      );

    assert
      .dom(".pswp__button--original-image")
      .hasAttribute("href", /\/images\/d-logo-sketch\.png$/);

    await click(".pswp__button--close");
  });

  test("Correctly escapes image caption", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".lightbox");

    await waitFor(".pswp--open");

    assert
      .dom(".pswp__caption .pswp__caption-title")
      .hasHtml(/^&lt;script&gt;image&lt;\/script&gt;/);
  });
});

acceptance("Lightbox - grid order", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    const topicResponse = cloneJSON(topicFixtures["/t/280/1.json"]);

    const anchor = (title) => `
      <a class="lightbox" href="/images/d-logo-sketch.png"
         data-large-src="/images/d-logo-sketch.png"
         data-target-width="640" data-target-height="480"
         title="${title}">
        <img src="/images/d-logo-sketch-small.png" width="640" height="480" alt="${title}">
        <div class="meta"><span class="informations">640×480</span></div>
      </a>
    `;

    topicResponse.post_stream.posts[0].cooked = `
      <div class="d-image-grid">
        ${anchor("img1")}
        ${anchor("img2")}
        ${anchor("img3")}
        ${anchor("img4")}
      </div>
    `;

    server.get("/t/280.json", () => helper.response(topicResponse));
    server.get("/t/280/:post_number.json", () =>
      helper.response(topicResponse)
    );
  });

  test("Arrow navigation follows original markdown order, not column-balanced DOM order", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(".d-image-grid .lightbox[title='img1']");
    await waitFor(".pswp--open");
    assert.dom(".pswp__caption-title").hasText("img1");

    for (const expected of ["img2", "img3", "img4"]) {
      await click(".pswp__button--arrow--next");
      await waitUntil(
        () =>
          document.querySelector(".pswp__caption-title")?.textContent ===
          expected
      );
      assert.dom(".pswp__caption-title").hasText(expected);
    }

    await click(".pswp__button--close");
  });
});
