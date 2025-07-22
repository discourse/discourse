import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { AUTO_GROUPS } from "discourse/lib/constants";
import {
  acceptance,
  count,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Mixed Ads", function (needs) {
  needs.user();
  needs.settings({
    house_ads_after_nth_post: 6,
    house_ads_frequency: 50,
    dfp_publisher_id: "MYdfpID",
    dfp_display_groups: [AUTO_GROUPS.trust_level_1, AUTO_GROUPS.trust_level_2],
    dfp_topic_list_top_code: "list_top_ad_unit",
    dfp_topic_list_top_ad_sizes: "728*90 - leaderboard",
    dfp_mobile_topic_list_top_code: "mobile_list_top_ad_unit",
    dfp_mobile_topic_list_top_ad_size: "300*250 - medium rectangle",
    dfp_post_bottom_code: "post_bottom_ad_unit",
    dfp_post_bottom_ad_sizes: "728*90 - leaderboard",
    dfp_mobile_post_bottom_code: "mobile_post_bottom_ad_unit",
    dfp_mobile_post_bottom_ad_size: "300*250 - medium rectangle",
    dfp_nth_post_code: 6,
  });
  needs.site({
    house_creatives: {
      settings: {
        topic_list_top: "Topic List",
        topic_above_post_stream: "Above Post Stream",
        topic_above_suggested: "Above Suggested",
        post_bottom: "Post",
        after_nth_post: 6,
      },
      creatives: {
        "Topic List": "<div class='h-topic-list'>TOPIC LIST</div>",
        "Above Post Stream":
          "<div class='h-above-post-stream'>ABOVE POST STREAM</div>",
        "Above Suggested":
          "<div class='h-above-suggested'>ABOVE SUGGESTED</div>",
        Post: "<div class='h-post'>BELOW POST</div>",
      },
    },
  });

  test("correct ads show", async (assert) => {
    updateCurrentUser({
      staff: false,
      trust_level: 1,
      show_dfp_ads: true,
      show_to_groups: true,
    });
    await visit("/t/280"); // 20 posts

    const houseAdsCount = count(".house-creative");
    const dfpAdsCount = count(".google-dfp-ad");

    assert.true(houseAdsCount > 1);
    assert.true(houseAdsCount < 4);
    assert.true(dfpAdsCount > 1);
    assert.true(dfpAdsCount < 4);

    await visit("/latest");
    assert
      .dom(".h-topic-list-top, .dfp-ad-topic-list-top")
      .exists({ count: 1 }, "it should render ad above topic list");
  });
});
