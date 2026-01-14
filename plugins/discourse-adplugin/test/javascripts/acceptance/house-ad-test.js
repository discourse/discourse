import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

acceptance(`House Ads`, function (needs) {
  needs.user();
  needs.settings({
    no_ads_for_categories: "1",
    house_ads_after_nth_post: 6,
    house_ads_after_nth_topic: 3,
  });
  needs.site({
    house_creatives: {
      settings: {
        topic_list_top: "Topic List Top",
        topic_above_post_stream: "Above Post Stream",
        topic_above_suggested: "Above Suggested",
        post_bottom: "Post",
        topic_list_between: "Between Topic List",
        after_nth_post: 6,
        after_nth_topic: 6,
      },
      creatives: {
        "Topic List Top": {
          html: "<div class='h-topic-list'>TOPIC LIST TOP</div>",
          category_ids: [],
        },
        "Above Post Stream": {
          html: "<div class='h-above-post-stream'>ABOVE POST STREAM</div>",
          category_ids: [],
        },
        "Above Suggested": {
          html: "<div class='h-above-suggested'>ABOVE SUGGESTED</div>",
          category_ids: [],
        },
        Post: {
          html: "<div class='h-post'>BELOW POST</div>",
          category_ids: [],
        },
        "Between Topic List": {
          html: "<div class='h-between-topic-list'>BETWEEN TOPIC LIST</div>",
          category_ids: [],
        },
      },
    },
  });

  test("correct ads show", async function (assert) {
    updateCurrentUser({
      staff: false,
      trust_level: 1,
      show_to_groups: true,
    });
    await visit("/t/280"); // 20 posts

    assert
      .dom(".h-above-post-stream")
      .exists({ count: 1 }, "renders ad at top of topic");

    assert
      .dom(".h-above-suggested")
      .exists({ count: 1 }, "renders ad above suggested topics");

    assert.dom(".h-post").exists({ count: 3 }, "renders 3 ads between posts");

    assert
      .dom("#post_6 + .ad-connector .h-post")
      .exists({ count: 1 }, "ad after 6th post");

    assert
      .dom("#post_12 + .ad-connector .h-post")
      .exists({ count: 1 }, "ad after 12th post");

    assert
      .dom("#post_18 + .ad-connector .h-post")
      .exists({ count: 1 }, "ad after 18th post");

    await visit("/latest");

    assert
      .dom(".h-topic-list")
      .exists({ count: 1 }, "renders ad above topic list");
    const originalTopAdElement = document.querySelector(".h-topic-list");

    assert
      .dom(".h-between-topic-list")
      .exists({ count: 5 }, "renders 5 ads between topics");

    await visit("/top");
    const newTopAdElement = document.querySelector(".h-topic-list");

    assert.notStrictEqual(
      originalTopAdElement,
      newTopAdElement,
      "ad is fully re-rendered when changing pages"
    );

    await visit("/t/28830");

    assert
      .dom(".h-above-post-stream")
      .doesNotExist(
        "no ad above post stream because category is in no_ads_for_categories"
      );

    assert
      .dom(".h-post")
      .doesNotExist(
        "no ad between posts because category is in no_ads_for_categories"
      );

    assert
      .dom(".h-above-suggested")
      .doesNotExist(
        "no ad above suggested because category is in no_ads_for_categories"
      );

    await visit("/c/bug");

    assert
      .dom(".h-topic-list")
      .doesNotExist(
        "no ad above category topic list because category is in no_ads_for_categories"
      );
  });
});

acceptance(
  `House Ads | Category and Group Permissions | Authenticated | Display Ad`,
  function (needs) {
    needs.user();
    needs.settings({
      no_ads_for_categories: "",
    });
    needs.site({
      house_creatives: {
        settings: {
          topic_list_top: "Topic List Top",
        },
        creatives: {
          "Topic List Top": {
            html: "<div class='h-topic-list'>TOPIC LIST TOP</div>",
            // match /c/bug/1
            category_ids: [1],
          },
        },
      },
    });

    test("displays ad to users when current category id is included in ad category_ids", async function (assert) {
      updateCurrentUser({
        staff: false,
        trust_level: 1,
        show_to_groups: true,
      });
      await visit("/c/bug/1");
      assert
        .dom(".h-topic-list")
        .exists(
          "ad is displayed above the topic list because the current category id is included in the ad category_ids"
        );
    });
  }
);

acceptance(
  `House Ads | Category and Group Permissions | Authenticated | Hide Ad`,
  function (needs) {
    needs.user();
    needs.settings({
      no_ads_for_categories: "",
    });
    needs.site({
      house_creatives: {
        settings: {
          topic_list_top: "Topic List Top",
        },
        creatives: {
          "Topic List Top": {
            html: "<div class='h-topic-list'>TOPIC LIST TOP</div>",
            // restrict ad to a different category than /c/bug/1
            category_ids: [2],
          },
        },
      },
    });

    test("hides ad to users when current category id is not included in ad category_ids", async function (assert) {
      updateCurrentUser({
        staff: false,
        trust_level: 1,
        show_to_groups: true,
      });
      await visit("/c/bug/1");
      assert
        .dom(".h-topic-list")
        .doesNotExist(
          "ad is not displayed because the current category id is not included in the ad category_ids"
        );
    });
  }
);

acceptance(
  `House Ads | Category and Group Permissions | Anonymous | Hide Ad`,
  function (needs) {
    needs.settings({
      no_ads_for_categories: "",
    });
    needs.site({
      house_creatives: {
        settings: {
          topic_list_top: "Topic List Top",
        },
        creatives: {
          "Topic List Top": {
            html: "<div class='h-topic-list'>TOPIC LIST TOP</div>",
            // restrict ad to a different category than /c/bug/1
            category_ids: [2],
          },
        },
      },
    });

    test("hides ad to anon users when current category id is not included in ad category_ids", async function (assert) {
      await visit("/c/bug/1");
      assert
        .dom(".h-topic-list")
        .doesNotExist(
          "ad is not displayed because the current category id is not included in the ad category_ids"
        );
    });
  }
);

acceptance(
  `House Ads | Category and Group Permissions | Anonymous | Hide Ad`,
  function (needs) {
    needs.settings({
      no_ads_for_categories: "",
    });
    needs.site({
      house_creatives: {
        settings: {
          topic_list_top: "Topic List Top",
        },
        creatives: {
          "Topic List Top": {
            html: "<div class='h-topic-list'>TOPIC LIST TOP</div>",
            // restrict ad to a different category than /c/bug/1
            category_ids: [2],
          },
        },
      },
    });

    test("hides ad to anon users when current category id is not included in ad category_ids", async function (assert) {
      await visit("/c/bug/1");
      assert
        .dom(".h-topic-list")
        .doesNotExist(
          "ad is not displayed because the current category id is not included in the ad category_ids"
        );
    });
  }
);

acceptance(
  `House Ads | Category and Group Permissions | Anonymous | Show Ad`,
  function (needs) {
    needs.settings({
      no_ads_for_categories: "",
    });
    needs.site({
      house_creatives: {
        settings: {
          topic_list_top: "Topic List Top",
        },
        creatives: {
          "Topic List Top": {
            html: "<div class='h-topic-list'>TOPIC LIST TOP</div>",
            // match /c/bug/1
            category_ids: [1],
          },
        },
      },
    });

    test("shows ad to anon users when current category id is included in ad category_ids", async function (assert) {
      await visit("/c/bug/1");
      assert
        .dom(".h-topic-list")
        .exists(
          "ad is displayed because the current category id is included in the ad category_ids"
        );
    });
  }
);

acceptance(
  `House Ads | Category and Group Permissions | Anonymous | Show non-restricted ads`,
  function (needs) {
    needs.settings({
      no_ads_for_categories: "",
    });
    needs.site({
      house_creatives: {
        settings: {
          topic_list_top: "Topic List Top One|Topic List Top Two",
        },
        creatives: {
          "Topic List Top One": {
            html: "<div class='h-topic-list-one'>TOPIC LIST TOP ONE</div>",
            category_ids: [2],
          },
          "Topic List Top Two": {
            html: "<div class='h-topic-list-two'>TOPIC LIST TOP TWO</div>",
            category_ids: [],
          },
        },
      },
    });

    test("shows non-restricted ad to anon users", async function (assert) {
      await visit("/c/bug/1");
      assert.dom(".h-topic-list-two").exists("non-restricted ad is displayed");
    });
  }
);
