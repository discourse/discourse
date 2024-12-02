import {
  click,
  triggerEvent,
  triggerKeyEvent,
  visit,
  waitFor,
} from "@ember/test-helpers";
import { skip, test } from "qunit";
import sinon from "sinon";
import { SELECTORS } from "discourse/lib/lightbox/constants";
import topicFixtures from "discourse/tests/fixtures/topic";
import {
  generateLightboxMarkup,
  LIGHTBOX_IMAGE_FIXTURES,
} from "discourse/tests/helpers/lightbox-helpers";
import {
  acceptance,
  chromeTest,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import i18n from "discourse-i18n";

async function waitForLoad() {
  return await waitFor(".d-lightbox.is-finished-loading", {
    timeout: 5000,
  });
}

const singleLargeImageMarkup = `
${generateLightboxMarkup(LIGHTBOX_IMAGE_FIXTURES.first)}`;

const singleSmallImageMarkup = `
${generateLightboxMarkup(LIGHTBOX_IMAGE_FIXTURES.smallerThanViewPort)}
`;

const multipleLargeImagesMarkup = `
${generateLightboxMarkup(LIGHTBOX_IMAGE_FIXTURES.first)}
${generateLightboxMarkup(LIGHTBOX_IMAGE_FIXTURES.second)}
${generateLightboxMarkup(LIGHTBOX_IMAGE_FIXTURES.third)}
`;

const markupWithInvalidImage = `
${generateLightboxMarkup(LIGHTBOX_IMAGE_FIXTURES.first)}
${generateLightboxMarkup(LIGHTBOX_IMAGE_FIXTURES.invalidImage)}
${generateLightboxMarkup(LIGHTBOX_IMAGE_FIXTURES.second)}`;

function setupPretender(server, helper, markup) {
  const topicResponse = cloneJSON(topicFixtures["/t/280/1.json"]);
  let markupFromArray = Array.isArray(markup);
  let responseTotal = markupFromArray ? markup.length : 1;

  for (let i = 0; i < responseTotal; i++) {
    topicResponse.post_stream.posts[i].cooked += markupFromArray
      ? markup[i]
      : markup;
  }

  server.get("/t/280.json", () => helper.response(topicResponse));
  server.get("/t/280/:post_number.json", () => helper.response(topicResponse));
}

acceptance("Experimental Lightbox - site setting", function (needs) {
  needs.pretender((server, helper) =>
    setupPretender(server, helper, singleLargeImageMarkup)
  );

  test("does not interfere with Magnific when enable_experimental_lightbox is disabled", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();

    await click(".mfp-close");
  });
});

acceptance("Experimental Lightbox - layout single image", function (needs) {
  needs.settings({ enable_experimental_lightbox: true });

  needs.pretender((server, helper) =>
    setupPretender(server, helper, singleLargeImageMarkup)
  );

  test("shows the correct elements for a single-image lightbox", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();

    await waitForLoad();

    assert.dom(".d-lightbox__main-title").exists();

    assert
      .dom(SELECTORS.ACTIVE_ITEM_TITLE)
      .hasText(LIGHTBOX_IMAGE_FIXTURES.first.title);

    assert
      .dom(SELECTORS.ACTIVE_ITEM_FILE_DETAILS)
      .hasText(LIGHTBOX_IMAGE_FIXTURES.first.fileDetails);

    assert.dom(SELECTORS.CLOSE_BUTTON).exists();
    assert.dom(SELECTORS.CLOSE_BUTTON).isFocused();
    assert.dom(SELECTORS.TAB_BUTTON).exists();
    assert.dom(SELECTORS.FULL_SCREEN_BUTTON).exists();
    assert.dom(SELECTORS.ROTATE_BUTTON).exists();
    assert.dom(SELECTORS.ZOOM_BUTTON).exists();
    assert.dom(SELECTORS.DOWNLOAD_BUTTON).exists();
    assert.dom(SELECTORS.PREV_BUTTON).doesNotExist();
    assert.dom(SELECTORS.NEXT_BUTTON).doesNotExist();
    assert.dom(SELECTORS.MULTI_BUTTONS).doesNotExist();
    assert.dom(SELECTORS.CAROUSEL).doesNotExist();
    assert.dom(SELECTORS.MAIN_IMAGE).exists();
    assert.dom(SELECTORS.MAIN_IMAGE).hasAttribute("src");

    assert.dom(".d-lightbox__error-message").doesNotExist();

    assert
      .dom(SELECTORS.MAIN_IMAGE)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL);

    assert.dom(".d-lightbox.is-fullscreen").doesNotExist();
    assert.dom(".d-lightbox.is-rotated").doesNotExist();
    assert.dom(".d-lightbox.is-zoomed").doesNotExist();
    assert.dom(".d-lightbox__backdrop").exists();

    await click(SELECTORS.CLOSE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();
  });
});

acceptance("Experimental Lightbox - layout multiple images", function (needs) {
  needs.settings({ enable_experimental_lightbox: true });

  needs.pretender((server, helper) =>
    setupPretender(server, helper, multipleLargeImagesMarkup)
  );

  test("shows multiple image controls when there's more than one item", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);
    await waitForLoad();

    assert.dom(SELECTORS.CAROUSEL).exists();
    await click(SELECTORS.CAROUSEL_BUTTON);

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();
    assert.dom(SELECTORS.PREV_BUTTON).exists();
    assert.dom(SELECTORS.NEXT_BUTTON).exists();
    assert.dom(SELECTORS.MULTI_BUTTONS).exists();
    assert.dom(SELECTORS.COUNTERS).exists();
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("1");
    assert.dom(SELECTORS.COUNTER_TOTAL).hasText("3");

    await click(SELECTORS.CLOSE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();
  });
});

acceptance("Experimental Lightbox - interaction", function (needs) {
  needs.settings({ enable_experimental_lightbox: true });

  needs.pretender((server, helper) =>
    setupPretender(server, helper, multipleLargeImagesMarkup)
  );

  test("handles zoom", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();

    await waitForLoad();
    assert.dom(".d-lightbox.is-zoomed").doesNotExist();

    await click(SELECTORS.ZOOM_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).hasClass("is-zoomed");
    assert.dom(SELECTORS.ACTIVE_ITEM_TITLE).doesNotExist();

    await click(SELECTORS.ZOOM_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).doesNotHaveClass("is-zoomed");
    assert.dom(SELECTORS.ACTIVE_ITEM_TITLE).exists();

    await click(SELECTORS.MAIN_IMAGE);
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).hasClass("is-zoomed");

    await click(".d-lightbox__zoomed-image-container");
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).doesNotHaveClass("is-zoomed");

    await click(SELECTORS.CLOSE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();
  });

  test("handles rotation", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).exists();

    await waitForLoad();
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).doesNotHaveClass("is-rotated");

    await click(SELECTORS.ROTATE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).hasClass("is-rotated");
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).hasClass("is-rotated-90");

    await click(SELECTORS.ROTATE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).hasClass("is-rotated-180");

    await click(SELECTORS.ROTATE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).hasClass("is-rotated-270");

    await click(SELECTORS.ROTATE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).doesNotHaveClass("is-rotated");

    await click(SELECTORS.CLOSE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();
  });

  test("handles navigation - next", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("1");
    assert.dom(SELECTORS.COUNTER_TOTAL).hasText("3");

    await waitForLoad();
    await click(SELECTORS.CAROUSEL_BUTTON);

    assert
      .dom(SELECTORS.MAIN_IMAGE)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL);

    await click(SELECTORS.NEXT_BUTTON);
    await waitForLoad();

    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("2");

    assert
      .dom(SELECTORS.MAIN_IMAGE)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.second.fullsizeURL);

    await click(SELECTORS.NEXT_BUTTON);
    await waitForLoad();

    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("3");

    assert
      .dom(SELECTORS.MAIN_IMAGE)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.third.fullsizeURL);

    await click(SELECTORS.NEXT_BUTTON);
    await waitForLoad();

    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("1");

    assert
      .dom(SELECTORS.MAIN_IMAGE)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL);

    await click(SELECTORS.CLOSE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();
  });

  test("handles navigation - previous", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("1");
    assert.dom(SELECTORS.COUNTER_TOTAL).hasText("3");

    await waitForLoad();
    await click(SELECTORS.CAROUSEL_BUTTON);

    assert
      .dom(SELECTORS.MAIN_IMAGE)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL);

    await click(SELECTORS.PREV_BUTTON);
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("3");

    await waitForLoad();
    assert
      .dom(SELECTORS.MAIN_IMAGE)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.third.fullsizeURL);

    await click(SELECTORS.PREV_BUTTON);
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("2");

    await waitForLoad();
    assert
      .dom(SELECTORS.MAIN_IMAGE)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.second.fullsizeURL);

    await click(SELECTORS.PREV_BUTTON);
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("1");

    await waitForLoad();
    assert
      .dom(SELECTORS.MAIN_IMAGE)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL);

    await click(SELECTORS.CLOSE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();
  });

  test("handles navigation - opens at the correct index", async function (assert) {
    await visit("/t/internationalization-localization/280");
    const lightboxes = queryAll(SELECTORS.DEFAULT_ITEM_SELECTOR);

    await click(lightboxes[1]);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("2");
    assert.dom(SELECTORS.COUNTER_TOTAL).hasText("3");

    await waitForLoad();
    assert
      .dom(SELECTORS.MAIN_IMAGE)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.second.fullsizeURL);

    await click(SELECTORS.CLOSE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();

    await click(lightboxes[2]);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("3");
    assert.dom(SELECTORS.COUNTER_TOTAL).hasText("3");

    await waitForLoad();
    assert
      .dom(SELECTORS.MAIN_IMAGE)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.third.fullsizeURL);

    await click(SELECTORS.CLOSE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();
  });

  test(`handles navigation - prevents document scroll while the lightbox is open`, async function (assert) {
    await visit("/t/internationalization-localization/280");

    const classListAddStub = sinon.stub(
      document.documentElement.classList,
      "add"
    );
    const classListRemoveStub = sinon.stub(
      document.documentElement.classList,
      "remove"
    );

    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);
    await waitForLoad();

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();

    assert.true(
      classListAddStub.calledWith("has-lightbox"),
      "adds has-lightbox class to document element"
    );

    await click(SELECTORS.CLOSE_BUTTON);

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();

    assert.true(
      classListRemoveStub.calledWith("has-lightbox"),
      "removes has-lightbox class from document element"
    );

    classListAddStub.restore();
    classListRemoveStub.restore();
  });

  test("handles fullscreen", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).doesNotHaveClass("is-fullscreen");

    const requestFullscreenStub = sinon.stub(
      document.documentElement,
      "requestFullscreen"
    );

    const exitFullscreenStub = sinon.stub(document, "exitFullscreen");

    await click(SELECTORS.FULL_SCREEN_BUTTON);

    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).hasClass("is-fullscreen");
    assert.true(requestFullscreenStub.calledOnce, "calls requestFullscreen");

    await click(SELECTORS.FULL_SCREEN_BUTTON);

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotHaveClass("is-fullscreen");

    assert.true(exitFullscreenStub.calledOnce, "calls exitFullscreen");

    await click(SELECTORS.CLOSE_BUTTON);

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();

    requestFullscreenStub.restore();
    exitFullscreenStub.restore();
  });

  test("handles download", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();

    const clickStub = sinon.stub(HTMLAnchorElement.prototype, "click");

    // appends and clicks <a download="..." href="..."></a>
    await click(SELECTORS.DOWNLOAD_BUTTON);

    assert.true(clickStub.called, "The click method was called");

    await click(SELECTORS.CLOSE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();

    clickStub.restore();
  });

  test("handles newtab", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();

    const openStub = sinon.stub(window, "open");

    await click(SELECTORS.TAB_BUTTON);

    assert.true(openStub.called, "The open method was called");

    await click(SELECTORS.CLOSE_BUTTON);

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();

    openStub.restore();
  });

  test("handles close", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();

    await click(SELECTORS.CLOSE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();
  });

  test("handles focus", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();

    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);
    await waitForLoad();

    assert.dom(SELECTORS.CLOSE_BUTTON).isFocused();

    // tab forward
    Array(50)
      .fill()
      .forEach(async () => {
        await triggerKeyEvent(SELECTORS.LIGHTBOX_CONTENT, "keyup", 9);
      });

    // it keeps focus inside the lightbox when tabbing forward
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();

    // tab backward
    Array(50)
      .fill()
      .forEach(async () => {
        await triggerKeyEvent(SELECTORS.LIGHTBOX_CONTENT, "keyup", 9, {
          shiftKey: true,
        });
      });

    // it keeps focus inside the lightbox when tabbing backward
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();

    await click(SELECTORS.CLOSE_BUTTON);

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();

    // it restores focus in the main document when closed
    assert.dom(SELECTORS.DEFAULT_ITEM_SELECTOR).isFocused();
  });

  test("navigation - screen reader announcer", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const firstExpectedTitle = i18n.t(
      "experimental_lightbox.screen_reader_image_title",
      {
        current: 1,
        total: 3,
        title: LIGHTBOX_IMAGE_FIXTURES.first.title,
      }
    );

    const secondExpectedTitle = i18n.t(
      "experimental_lightbox.screen_reader_image_title",
      {
        current: 2,
        total: 3,
        title: LIGHTBOX_IMAGE_FIXTURES.second.title,
      }
    );

    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);
    await waitForLoad();
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();

    assert.dom(".d-lightbox__screen-reader-announcer").exists();

    assert
      .dom(".d-lightbox__screen-reader-announcer")
      .hasText(firstExpectedTitle);

    // hide carousel so prev/next btns are visible
    await click(SELECTORS.CAROUSEL_BUTTON);

    await click(SELECTORS.NEXT_BUTTON);
    await waitForLoad();

    assert
      .dom(".d-lightbox__screen-reader-announcer")
      .hasText(secondExpectedTitle);

    await click(SELECTORS.CLOSE_BUTTON);

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();
  });

  // TODO: this test is flaky on firefox. It runs fine locally and the functionality works in a real session, but fails on CI.
  chromeTest("handles keyboard shortcuts", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();

    await waitForLoad();

    await triggerKeyEvent(SELECTORS.LIGHTBOX_CONTENT, "keyup", "ArrowRight");
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("2");

    await triggerKeyEvent(SELECTORS.LIGHTBOX_CONTENT, "keyup", "ArrowLeft");
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("1");

    await triggerKeyEvent(SELECTORS.LIGHTBOX_CONTENT, "keyup", "ArrowDown");
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("2");

    await triggerKeyEvent(SELECTORS.LIGHTBOX_CONTENT, "keyup", "ArrowUp");
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("1");

    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).doesNotHaveClass("is-zoomed");

    await triggerKeyEvent(SELECTORS.LIGHTBOX_CONTENT, "keyup", 90); // 'z' key
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).hasClass("is-zoomed");

    await triggerKeyEvent(SELECTORS.LIGHTBOX_CONTENT, "keyup", 90);
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).doesNotHaveClass("is-zoomed");

    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).doesNotHaveClass("is-rotated");
    await triggerKeyEvent(SELECTORS.LIGHTBOX_CONTENT, "keyup", 82); // r key
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).hasClass("is-rotated");

    await triggerKeyEvent(SELECTORS.LIGHTBOX_CONTENT, "keyup", 82);
    await triggerKeyEvent(SELECTORS.LIGHTBOX_CONTENT, "keyup", 82);
    await triggerKeyEvent(SELECTORS.LIGHTBOX_CONTENT, "keyup", 82);

    // back to original rotation
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).doesNotHaveClass("is-rotated");

    await triggerKeyEvent(SELECTORS.LIGHTBOX_CONTENT, "keyup", 65); // 'a' key
    assert.dom(SELECTORS.CAROUSEL).doesNotExist();

    await triggerKeyEvent(SELECTORS.LIGHTBOX_CONTENT, "keyup", 65); // 'a' key
    assert.dom(SELECTORS.CAROUSEL).exists();

    assert
      .dom(SELECTORS.LIGHTBOX_CONTAINER)
      .doesNotHaveClass("has-expanded-title");

    await triggerKeyEvent(SELECTORS.LIGHTBOX_CONTENT, "keyup", 84); // 't' key
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).hasClass("has-expanded-title");

    await triggerKeyEvent(SELECTORS.LIGHTBOX_CONTENT, "keyup", 84);
    assert
      .dom(SELECTORS.LIGHTBOX_CONTAINER)
      .doesNotHaveClass("has-expanded-title");

    const requestFullscreenStub = sinon.stub(
      document.documentElement,
      "requestFullscreen"
    );

    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).doesNotHaveClass("is-fullscreen");

    const exitFullscreenStub = sinon.stub(document, "exitFullscreen");

    await triggerKeyEvent(SELECTORS.LIGHTBOX_CONTENT, "keyup", 77); // 'm' key
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).hasClass("is-fullscreen");

    await triggerKeyEvent(SELECTORS.LIGHTBOX_CONTENT, "keyup", 77);
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).doesNotHaveClass("is-fullscreen");

    requestFullscreenStub.restore();
    exitFullscreenStub.restore();

    await triggerKeyEvent(SELECTORS.LIGHTBOX_CONTENT, "keydown", "Escape");
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();
  });
});

acceptance("Experimental Lightbox - carousel", function (needs) {
  needs.settings({ enable_experimental_lightbox: true });

  needs.pretender((server, helper) =>
    setupPretender(server, helper, [
      multipleLargeImagesMarkup + multipleLargeImagesMarkup,
      multipleLargeImagesMarkup,
    ])
  );

  test("navigation", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);
    await waitForLoad();

    // lightbox opens with the first image
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("1");

    // carousel is visible by default if there are multiple images
    assert.dom(SELECTORS.CAROUSEL).exists();
    assert.dom(SELECTORS.CAROUSEL_PREV_BUTTON).exists();
    assert.dom(SELECTORS.CAROUSEL_NEXT_BUTTON).exists();

    // carousel has 5 items and an active item
    assert.dom(SELECTORS.CAROUSEL_ITEM).exists({ count: 6 });
    assert.dom(SELECTORS.CAROUSEL_ITEM + ".is-current").exists();

    await waitForLoad();

    // carousel current item is the first image
    assert
      .dom(SELECTORS.CAROUSEL_ITEM + ".is-current")
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.first.smallURL);

    await click(SELECTORS.CAROUSEL_NEXT_BUTTON);
    await waitForLoad();

    // carousel next button works and current item is the second image
    assert
      .dom(SELECTORS.CAROUSEL_ITEM + ".is-current")
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.second.smallURL);

    await click(SELECTORS.CAROUSEL_PREV_BUTTON);
    await waitForLoad();

    // carousel previous button works and current item is the first image again
    assert
      .dom(SELECTORS.CAROUSEL_ITEM + ".is-current")
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.first.smallURL);

    await click(SELECTORS.CAROUSEL_ITEM + ":nth-child(3)");
    await waitForLoad();

    // carousel manual item selection works and current item is the third image
    assert
      .dom(SELECTORS.CAROUSEL_ITEM + ".is-current")
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.third.smallURL);

    // carousel closes after clicking the carousel button
    await click(SELECTORS.CAROUSEL_BUTTON);
    assert.dom(SELECTORS.CAROUSEL).doesNotExist();

    await click(SELECTORS.CLOSE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();
  });

  test("arrows are not shown when there are only a few images", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const lightboxes = [...queryAll(SELECTORS.DEFAULT_ITEM_SELECTOR)];

    const lastThreeLightboxes = lightboxes.slice(-6);

    lastThreeLightboxes.forEach((lightbox) => {
      lightbox.remove();
    });

    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);
    assert.dom(SELECTORS.LIGHTBOX_CONTAINER).exists();

    // carousel opens by default if there are more than 2 images
    assert.dom(SELECTORS.CAROUSEL).exists();
    assert.dom(SELECTORS.CAROUSEL_ITEM).exists({ count: 3 });

    // no prev/next buttons when carousel only has a few images
    assert.dom(SELECTORS.CAROUSEL_PREV_BUTTON).doesNotExist();
    assert.dom(SELECTORS.CAROUSEL_NEXT_BUTTON).doesNotExist();

    // carousel closes after clicking the button again
    await click(SELECTORS.CAROUSEL_BUTTON);
    assert.dom(SELECTORS.CAROUSEL).doesNotExist();

    await click(SELECTORS.CLOSE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();
  });

  test("images update when changing galleries", async function (assert) {
    await visit("/t/internationalization-localization/280");

    // click on image from first gallery
    await click("#post_1 " + SELECTORS.DEFAULT_ITEM_SELECTOR + ":nth-child(1)");

    // number of images in carousel matches first gallery
    assert.dom(SELECTORS.CAROUSEL_ITEM).exists({ count: 6 });

    await click(SELECTORS.CLOSE_BUTTON);

    // click on image from second gallery
    await click("#post_2 " + SELECTORS.DEFAULT_ITEM_SELECTOR + ":nth-child(1)");

    // number of images in carousel matches second gallery
    assert.dom(SELECTORS.CAROUSEL_ITEM).exists({ count: 3 });
  });
});

acceptance("Experimental Lightbox - mobile", function (needs) {
  needs.settings({ enable_experimental_lightbox: true });

  needs.pretender((server, helper) =>
    setupPretender(server, helper, multipleLargeImagesMarkup)
  );

  test("navigation - swipe navigation LTR", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("1");

    await triggerEvent(SELECTORS.LIGHTBOX_BODY, "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ screenX: 0, screenY: 0 }],
    });

    await triggerEvent(SELECTORS.LIGHTBOX_BODY, "touchend", {
      changedTouches: [{ screenX: 150, screenY: 0 }],
      touches: [{ pageX: 150, pageY: 0 }],
    });

    // swiping left goes to the previous image
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("3");

    await triggerEvent(SELECTORS.LIGHTBOX_BODY, "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ screenX: 0, screenY: 0 }],
    });

    await triggerEvent(SELECTORS.LIGHTBOX_BODY, "touchend", {
      changedTouches: [{ screenX: -150, screenY: 0 }],
      touches: [{ pageX: 150, pageY: 0 }],
    });

    // swiping right goes to the next image
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("1");

    await click(SELECTORS.CLOSE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();
  });

  test("navigation - swipe navigation RTL", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("1");

    const containsStub = sinon.stub(
      document.documentElement.classList,
      "contains"
    );

    containsStub.withArgs("rtl").returns(true);

    await triggerEvent(SELECTORS.LIGHTBOX_BODY, "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ screenX: 0, screenY: 0 }],
    });

    await triggerEvent(SELECTORS.LIGHTBOX_BODY, "touchend", {
      changedTouches: [{ screenX: -150, screenY: 0 }],
      touches: [{ pageX: 150, pageY: 0 }],
    });

    // swiping left goes to the next image in RTL
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("2");

    await triggerEvent(SELECTORS.LIGHTBOX_BODY, "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ screenX: 0, screenY: 0 }],
    });

    await triggerEvent(SELECTORS.LIGHTBOX_BODY, "touchend", {
      changedTouches: [{ screenX: 150, screenY: 0 }],
      touches: [{ pageX: 150, pageY: 0 }],
    });

    // swiping right goes to the previous image in RTL
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("1");

    containsStub.restore();

    await click(SELECTORS.CLOSE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();
  });

  test("navigation - swipe close", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();

    await triggerEvent(SELECTORS.LIGHTBOX_BODY, "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ screenX: 0, screenY: 0 }],
    });

    await triggerEvent(SELECTORS.LIGHTBOX_BODY, "touchend", {
      changedTouches: [{ screenX: 0, screenY: 150 }],
      touches: [{ pageX: 0, pageY: 150 }],
    });

    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();
  });
});

acceptance("Experimental Lightbox - loading state", function (needs) {
  needs.settings({ enable_experimental_lightbox: true });

  needs.pretender((server, helper) =>
    setupPretender(server, helper, markupWithInvalidImage)
  );

  skip("handles loading errors", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).exists();

    await waitForLoad();

    // the image has the correct src
    assert
      .dom(SELECTORS.MAIN_IMAGE)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL);

    await click(SELECTORS.NEXT_BUTTON);

    // does not show an image if it can't be loaded
    assert.dom(SELECTORS.MAIN_IMAGE).doesNotExist();

    await click(SELECTORS.NEXT_BUTTON);

    // it shows the correct image when navigating after an error
    assert.dom(SELECTORS.COUNTER_CURRENT).hasText("3");

    await waitForLoad();

    assert
      .dom(SELECTORS.MAIN_IMAGE)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.second.fullsizeURL);

    await click(SELECTORS.CLOSE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();
  });
});

acceptance("Experimental Lightbox - conditional buttons", function (needs) {
  needs.settings({
    enable_experimental_lightbox: true,
    prevent_anons_from_downloading_files: true,
  });

  needs.pretender((server, helper) =>
    setupPretender(server, helper, singleSmallImageMarkup)
  );

  test("doesn't show the newtab and download buttons to anons if prevent_anons_from_downloading_files is enabled", async function (assert) {
    this.siteSettings.prevent_anons_from_downloading_files = true;
    await visit("/t/internationalization-localization/280");
    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);

    // it does not show the newtab or download button
    assert.dom(SELECTORS.TAB_BUTTON).doesNotExist();
    assert.dom(SELECTORS.DOWNLOAD_BUTTON).doesNotExist();
  });

  test("doesn't show the zoom button if the image is smaller than the viewport", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(SELECTORS.DEFAULT_ITEM_SELECTOR);
    assert.dom(SELECTORS.ZOOM_BUTTON).doesNotExist();

    await click(SELECTORS.CLOSE_BUTTON);
    assert.dom(SELECTORS.LIGHTBOX_CONTENT).doesNotExist();
  });
});
