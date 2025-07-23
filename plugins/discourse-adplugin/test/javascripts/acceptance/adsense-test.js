import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { AUTO_GROUPS } from "discourse/lib/constants";
import groupFixtures from "discourse/tests/fixtures/group-fixtures";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

["enabled", "disabled"].forEach((postStreamMode) => {
  acceptance(
    `AdSense (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.user();
      needs.settings({
        no_ads_for_groups: "47",
        no_ads_for_categories: "1",
        adsense_publisher_code: "MYADSENSEID",
        adsense_display_groups: [
          AUTO_GROUPS.trust_level_1,
          AUTO_GROUPS.trust_level_2,
        ],
        adsense_topic_list_top_code: "list_top_ad_unit",
        adsense_topic_list_top_ad_sizes: "728*90 - leaderboard",
        adsense_mobile_topic_list_top_code: "mobile_list_top_ad_unit",
        adsense_mobile_topic_list_top_ad_size: "300*250 - medium rectangle",
        adsense_post_bottom_code: "post_bottom_ad_unit",
        adsense_post_bottom_ad_sizes: "728*90 - leaderboard",
        adsense_mobile_post_bottom_code: "mobile_post_bottom_ad_unit",
        adsense_mobile_post_bottom_ad_size: "300*250 - medium rectangle",
        adsense_nth_post_code: 6,
        adsense_topic_above_post_stream_code: "above_post_stream_ad_unit",
        adsense_topic_above_post_stream_ad_sizes: "728*90 - leaderboard",
        glimmer_post_stream_mode: postStreamMode,
      });
      needs.site({
        house_creatives: {
          settings: {
            topic_list_top: "",
            topic_above_post_stream: "",
            topic_above_suggested: "",
            post_bottom: "",
            after_nth_post: 20,
          },
          creatives: {},
        },
      });

      test("correct number of ads should show", async (assert) => {
        updateCurrentUser({
          staff: false,
          trust_level: 1,
          groups: [AUTO_GROUPS.trust_level_1],
          show_adsense_ads: true,
          show_to_groups: true,
        });
        await visit("/t/280"); // 20 posts

        assert
          .dom(".google-adsense.adsense-topic-above-post-stream")
          .exists({ count: 1 }, "it should render 1 ad above post stream");

        assert
          .dom(".google-adsense.adsense-post-bottom")
          .exists({ count: 3 }, "it should render 3 ads");

        assert
          .dom("#post_6 + .ad-connector .google-adsense.adsense-post-bottom")
          .exists({ count: 1 }, "ad after 6th post");

        assert
          .dom("#post_12 + .ad-connector .google-adsense.adsense-post-bottom")
          .exists({ count: 1 }, "ad after 12th post");

        assert
          .dom("#post_18 + .ad-connector .google-adsense.adsense-post-bottom")
          .exists({ count: 1 }, "ad after 18th post");
      });

      test("no ads for trust level 3", async (assert) => {
        updateCurrentUser({
          staff: false,
          trust_level: 3,
          groups: [AUTO_GROUPS.trust_level_3],
        });
        await visit("/t/280");
        assert
          .dom(".google-adsense.adsense-post-bottom")
          .doesNotExist("it should render 0 ads");
      });

      test("can omit ads based on groups", async (assert) => {
        updateCurrentUser({
          staff: false,
          trust_level: 1,
          groups: [groupFixtures["/groups/discourse.json"].group],
        });
        await visit("/t/280");
        assert
          .dom(".google-adsense.adsense-post-bottom")
          .doesNotExist("it should render 0 ads");
      });

      test("can omit ads based on category", async (assert) => {
        updateCurrentUser({ staff: false, trust_level: 1 });
        await visit("/t/28830");
        assert
          .dom(".google-adsense.adsense-topic-above-post-stream")
          .doesNotExist("it should render 0 ads");
      });
    }
  );
});
