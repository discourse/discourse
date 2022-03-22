import { click, visit } from "@ember/test-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

acceptance("Lightbox", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    const topicResponse = cloneJSON(topicFixtures["/t/280/1.json"]);
    topicResponse.post_stream.posts[0].cooked += `<div class="lightbox-wrapper">
      <a class="lightbox" href="//discourse.local/uploads/default/original/1X/ad768537789cdf4679a18161ac0b0b6f0f4ccf9e.jpeg" data-download-href="//discourse.local/uploads/default/ad768537789cdf4679a18161ac0b0b6f0f4ccf9e" title="image">
        <img src="//discourse.local/uploads/default/optimized/1X/ad768537789cdf4679a18161ac0b0b6f0f4ccf9e_2_690x387.jpeg" alt="image" data-base62-sha1="oKwwVE8qLWFBkE5UJeCs2EwxHHg" width="690" height="387" srcset="//discourse.local/uploads/default/optimized/1X/ad768537789cdf4679a18161ac0b0b6f0f4ccf9e_2_690x387.jpeg, //discourse.local/uploads/default/optimized/1X/ad768537789cdf4679a18161ac0b0b6f0f4ccf9e_2_1035x580.jpeg 1.5x, //discourse.local/uploads/default/optimized/1X/ad768537789cdf4679a18161ac0b0b6f0f4ccf9e_2_1380x774.jpeg 2x" data-small-upload="//discourse.local/uploads/default/optimized/1X/ad768537789cdf4679a18161ac0b0b6f0f4ccf9e_2_10x10.png">
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

  test("Shows download and direct URL", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".lightbox");

    assert.equal(
      query(".mfp-title").textContent,
      "image · 1500×842 234 KB · download · original image"
    );

    assert.equal(
      query(".image-source-link:nth-child(1)").href,
      "http://discourse.local/uploads/default/ad768537789cdf4679a18161ac0b0b6f0f4ccf9e"
    );

    assert.equal(
      query(".image-source-link:nth-child(2)").href,
      "http://discourse.local/uploads/default/original/1X/ad768537789cdf4679a18161ac0b0b6f0f4ccf9e.jpeg"
    );

    await click(".mfp-close");
  });
});
