import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

// house_ads_frequency should also throttle how often a house ad appears
// when NO ad networks are configured -- i.e. house ads are the only ad
// type. Today the ad-slot short-circuits when there is a single available
// ad type and never consults house_ads_frequency, so a house ad shows on
// every eligible slot regardless of the setting. Sites that run only
// house ads (and want the slot to feel novel / not banner-blind) currently
// have to fake this with "blank" creatives.
//
// Intended behaviour:
//   - 100% (or unset): a house ad always shows  (unchanged)
//   - 0%:              no house ad shows
//   - N% (0<N<100):    a house ad shows roughly N% of eligible slots
//
// The boundary cases (0 and 100) are deterministic and pinned below. The
// intermediate percentage is probabilistic, so it is exercised by unit
// tests around the gating function rather than asserted by exact count
// here.

function houseOnlySite(needs, frequency) {
  needs.site({
    house_creatives: {
      settings: {
        topic_list_top: "Topic List",
        topic_above_post_stream: "Above Post Stream",
        post_bottom: "Post",
        after_nth_post: 1,
        // The client reads frequency from house_creatives.settings (the
        // server populates it from the SiteSetting); set it here directly.
        house_ads_frequency: frequency,
      },
      creatives: {
        "Topic List": "<div class='h-topic-list'>TOPIC LIST</div>",
        "Above Post Stream":
          "<div class='h-above-post-stream'>ABOVE POST STREAM</div>",
        Post: "<div class='h-post'>BELOW POST</div>",
      },
    },
  });
}

acceptance(
  "House Ad Frequency - house ads only, frequency 100",
  function (needs) {
    needs.user();
    needs.settings({ house_ads_after_nth_post: 1, house_ads_frequency: 100 });
    houseOnlySite(needs, 100);

    test("house ad always shows at 100%", async function (assert) {
      updateCurrentUser({ staff: false, trust_level: 1 });
      await visit("/t/280");

      assert
        .dom(".house-creative")
        .exists("house ad renders when frequency is 100% and no networks");
    });
  }
);

acceptance(
  "House Ad Frequency - house ads only, frequency 0",
  function (needs) {
    needs.user();
    needs.settings({ house_ads_after_nth_post: 1, house_ads_frequency: 0 });
    houseOnlySite(needs, 0);

    test("no house ad shows at 0%", async function (assert) {
      updateCurrentUser({ staff: false, trust_level: 1 });
      await visit("/t/280");

      assert
        .dom(".house-creative")
        .doesNotExist(
          "house ad is suppressed when frequency is 0%, even with no networks configured"
        );
    });
  }
);
