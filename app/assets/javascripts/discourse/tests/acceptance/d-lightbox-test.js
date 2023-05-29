import {
  LIGHTBOX_IMAGE_FIXTURES,
  generateLightboxMarkup,
} from "discourse/tests/helpers/lightbox-helpers";
import {
  acceptance,
  chromeTest,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import {
  click,
  triggerEvent,
  triggerKeyEvent,
  visit,
  waitUntil,
} from "@ember/test-helpers";

import { cloneJSON } from "discourse-common/lib/object";
import i18n from "I18n";
import sinon from "sinon";
import { test } from "qunit";
import topicFixtures from "discourse/tests/fixtures/topic";

async function waitForLoad() {
  return await waitUntil(
    () => document.querySelector(".d-lightbox--is-finished-loading"),
    {
      timeout: 5000,
    }
  );
}

const trigger_selector = ".lightbox";
const lightbox_selector = ".d-lightbox";
const lightbox_open_selector = ".d-lightbox__content";
const lightbox_body_selector = ".d-lightbox__body";
// header
const new_tab_btn_selector = ".d-lightbox__new-tab-button";
const fullscreen_btn_selector = ".d-lightbox__full-screen-button";
const close_btn_selector = ".d-lightbox__close-button";
const carousel_btn_selector = ".d-lightbox__carousel-button";
const carousel_multi_btns_selector = ".d-lightbox__multi-item-controls";
// body
const main_img_selector = ".d-lightbox__main-image";
const prev_btn_selector = ".d-lightbox__previous-button";
const next_btn_selector = ".d-lightbox__next-button";
// footer
const zoom_btn_selector = ".d-lightbox__zoom-button";
const rotate_btn_selector = ".d-lightbox__rotate-button";
const download_btn_selector = ".d-lightbox__download-button";
const item_title_selector = ".d-lightbox__item-title";
const item_file_details_selector = ".d-lightbox__item-file-details";
// carousel controls
const carousel_selector = ".d-lightbox__carousel";
const carousel_item_selector = ".d-lightbox__carousel-item";
const carousel_prev_btn_selector = ".d-lightbox__carousel-previous-button";
const carousel_next_btn_selector = ".d-lightbox__carousel-next-button";
const counter_current_selector = ".d-lightbox__counter-current";
const counter_total_selector = ".d-lightbox__counter-total";

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
  topicResponse.post_stream.posts[0].cooked += markup;

  server.get("/t/280.json", () => helper.response(topicResponse));
  server.get("/t/280/:post_number.json", () => helper.response(topicResponse));
}

acceptance("Experimental Lightbox - site setting", function (needs) {
  needs.pretender((server, helper) =>
    setupPretender(server, helper, singleLargeImageMarkup)
  );

  test("it does not interfere with Magnific when enable_experimental_lightbox is disabled", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(trigger_selector);

    assert.dom(lightbox_open_selector).doesNotExist();

    await click(".mfp-close");
  });
});

acceptance("Experimental Lightbox - layout single image", function (needs) {
  needs.settings({ enable_experimental_lightbox: true });

  needs.pretender((server, helper) =>
    setupPretender(server, helper, singleLargeImageMarkup)
  );

  test("it shows the correct elements for a single-image lightbox", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(trigger_selector);

    assert.dom(lightbox_open_selector).exists();

    await waitForLoad();

    assert.dom(".d-lightbox__main-title").exists();

    assert
      .dom(item_title_selector)
      .hasText(LIGHTBOX_IMAGE_FIXTURES.first.title);

    assert
      .dom(item_file_details_selector)
      .hasText(LIGHTBOX_IMAGE_FIXTURES.first.fileDetails);

    assert.dom(close_btn_selector).exists();
    assert.dom(close_btn_selector).isFocused();
    assert.dom(new_tab_btn_selector).exists();
    assert.dom(fullscreen_btn_selector).exists();
    assert.dom(rotate_btn_selector).exists();
    assert.dom(zoom_btn_selector).exists();
    assert.dom(download_btn_selector).exists();
    assert.dom(prev_btn_selector).doesNotExist();
    assert.dom(next_btn_selector).doesNotExist();
    assert.dom(carousel_multi_btns_selector).doesNotExist();
    assert.dom(carousel_selector).doesNotExist();
    assert.dom(main_img_selector).exists();
    assert.dom(main_img_selector).hasAttribute("src");

    assert.dom(".d-lightbox__error-message").doesNotExist();

    assert
      .dom(main_img_selector)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL);

    assert.dom(".d-lightbox--is-fullscreen").doesNotExist();
    assert.dom(".d-lightbox--is-rotated").doesNotExist();
    assert.dom(".d-lightbox--is-zoomed").doesNotExist();
    assert.dom(".d-lightbox__backdrop").exists();

    await click(close_btn_selector);
    assert.dom(lightbox_open_selector).doesNotExist();
  });
});

acceptance("Experimental Lightbox - layout multiple images", function (needs) {
  needs.settings({ enable_experimental_lightbox: true });

  needs.pretender((server, helper) =>
    setupPretender(server, helper, multipleLargeImagesMarkup)
  );

  test("it shows multiple image controls when there's more than one item", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(trigger_selector);
    await waitForLoad();
    assert.dom(lightbox_open_selector).exists();
    assert.dom(prev_btn_selector).exists();
    assert.dom(next_btn_selector).exists();
    assert.dom(carousel_multi_btns_selector).exists();
    assert.dom(".d-lightbox__counters").exists();
    assert.dom(counter_current_selector).hasText("1");
    assert.dom(counter_total_selector).hasText("3");
    assert.dom(carousel_selector).doesNotExist();

    await click(close_btn_selector);
    assert.dom(lightbox_open_selector).doesNotExist();
  });
});

acceptance("Experimental Lightbox - interaction", function (needs) {
  needs.settings({ enable_experimental_lightbox: true });

  needs.pretender((server, helper) =>
    setupPretender(server, helper, multipleLargeImagesMarkup)
  );

  test("handles zoom", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(trigger_selector);
    assert.dom(lightbox_open_selector).exists();

    await waitForLoad();
    assert.dom(".d-lightbox--is-zoomed").doesNotExist();

    await click(zoom_btn_selector);
    assert.dom(lightbox_selector).hasClass("d-lightbox--is-zoomed");
    assert.dom(item_title_selector).doesNotExist();

    await click(zoom_btn_selector);
    assert.dom(lightbox_selector).doesNotHaveClass("d-lightbox--is-zoomed");
    assert.dom(item_title_selector).exists();

    await click(main_img_selector);
    assert.dom(lightbox_selector).hasClass("d-lightbox--is-zoomed");

    await click(".d-lightbox__zoomed-image-container");
    assert.dom(lightbox_selector).doesNotHaveClass("d-lightbox--is-zoomed");

    await click(close_btn_selector);
    assert.dom(lightbox_open_selector).doesNotExist();
  });

  test("handles rotation", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(trigger_selector);
    assert.dom(lightbox_selector).exists();

    await waitForLoad();
    assert.dom(lightbox_selector).doesNotHaveClass("d-lightbox--is-rotated");

    await click(rotate_btn_selector);
    assert.dom(lightbox_selector).hasClass("d-lightbox--is-rotated");
    assert.dom(lightbox_selector).hasClass("d-lightbox--is-rotated-90");

    await click(rotate_btn_selector);
    assert.dom(lightbox_selector).hasClass("d-lightbox--is-rotated-180");

    await click(rotate_btn_selector);
    assert.dom(lightbox_selector).hasClass("d-lightbox--is-rotated-270");

    await click(rotate_btn_selector);
    assert.dom(lightbox_selector).doesNotHaveClass("d-lightbox--is-rotated");

    await click(close_btn_selector);
    assert.dom(lightbox_open_selector).doesNotExist();
  });

  test("handles navigation - next", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(trigger_selector);

    assert.dom(lightbox_open_selector).exists();
    assert.dom(counter_current_selector).hasText("1");
    assert.dom(counter_total_selector).hasText("3");

    await waitForLoad();

    assert
      .dom(main_img_selector)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL);

    await click(next_btn_selector);
    await waitForLoad();

    assert.dom(counter_current_selector).hasText("2");

    assert
      .dom(main_img_selector)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.second.fullsizeURL);

    await click(next_btn_selector);
    await waitForLoad();

    assert.dom(counter_current_selector).hasText("3");

    assert
      .dom(main_img_selector)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.third.fullsizeURL);

    await click(next_btn_selector);
    await waitForLoad();

    assert.dom(counter_current_selector).hasText("1");

    assert
      .dom(main_img_selector)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL);

    await click(close_btn_selector);
    assert.dom(lightbox_open_selector).doesNotExist();
  });

  test("handles navigation - previous", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(trigger_selector);

    assert.dom(lightbox_open_selector).exists();
    assert.dom(counter_current_selector).hasText("1");
    assert.dom(counter_total_selector).hasText("3");

    await waitForLoad();
    assert
      .dom(main_img_selector)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL);

    await click(prev_btn_selector);
    assert.dom(counter_current_selector).hasText("3");

    await waitForLoad();
    assert
      .dom(main_img_selector)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.third.fullsizeURL);

    await click(prev_btn_selector);
    assert.dom(counter_current_selector).hasText("2");

    await waitForLoad();
    assert
      .dom(main_img_selector)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.second.fullsizeURL);

    await click(prev_btn_selector);
    assert.dom(counter_current_selector).hasText("1");

    await waitForLoad();
    assert
      .dom(main_img_selector)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL);

    await click(close_btn_selector);
    assert.dom(lightbox_open_selector).doesNotExist();
  });

  test("handles navigation - opens at the correct index", async function (assert) {
    await visit("/t/internationalization-localization/280");
    const lightboxes = queryAll(trigger_selector);

    await click(lightboxes[1]);
    assert.dom(lightbox_open_selector).exists();
    assert.dom(counter_current_selector).hasText("2");
    assert.dom(counter_total_selector).hasText("3");

    await waitForLoad();
    assert
      .dom(main_img_selector)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.second.fullsizeURL);

    await click(close_btn_selector);
    assert.dom(lightbox_open_selector).doesNotExist();

    await click(lightboxes[2]);
    assert.dom(lightbox_open_selector).exists();
    assert.dom(counter_current_selector).hasText("3");
    assert.dom(counter_total_selector).hasText("3");

    await waitForLoad();
    assert
      .dom(main_img_selector)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.third.fullsizeURL);

    await click(close_btn_selector);
    assert.dom(lightbox_open_selector).doesNotExist();
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

    await click(trigger_selector);
    await waitForLoad();

    assert.dom(lightbox_open_selector).exists();

    assert.ok(
      classListAddStub.calledWith("has-lightbox"),
      "adds has-lightbox class to document element"
    );

    await click(close_btn_selector);

    assert.dom(lightbox_open_selector).doesNotExist();

    assert.ok(
      classListRemoveStub.calledWith("has-lightbox"),
      "removes has-lightbox class from document element"
    );

    classListAddStub.restore();
    classListRemoveStub.restore();
  });

  test("handles fullscreen", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(trigger_selector);

    assert.dom(lightbox_open_selector).exists();
    assert.dom(lightbox_selector).doesNotHaveClass("d-lightbox--is-fullscreen");

    const requestFullscreenStub = sinon.stub(
      document.documentElement,
      "requestFullscreen"
    );

    const exitFullscreenStub = sinon.stub(document, "exitFullscreen");

    await click(fullscreen_btn_selector);

    assert.dom(lightbox_selector).hasClass("d-lightbox--is-fullscreen");
    assert.ok(requestFullscreenStub.calledOnce, "it calls requestFullscreen");

    await click(fullscreen_btn_selector);

    assert
      .dom(lightbox_open_selector)
      .doesNotHaveClass("d-lightbox--is-fullscreen");

    assert.ok(exitFullscreenStub.calledOnce, "it calls exitFullscreen");

    await click(close_btn_selector);

    assert.dom(lightbox_open_selector).doesNotExist();

    requestFullscreenStub.restore();
    exitFullscreenStub.restore();
  });

  test("handles download", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(trigger_selector);

    assert.dom(lightbox_open_selector).exists();

    const clickStub = sinon.stub(HTMLAnchorElement.prototype, "click");

    // appends and clicks <a download="..." href="..."></a>
    await click(download_btn_selector);

    assert.ok(clickStub.called, "The click method was called");

    await click(close_btn_selector);
    assert.dom(lightbox_open_selector).doesNotExist();

    clickStub.restore();
  });

  test("handles newtab", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(trigger_selector);

    assert.dom(lightbox_open_selector).exists();

    const openStub = sinon.stub(window, "open");

    await click(new_tab_btn_selector);

    assert.ok(openStub.called, "The open method was called");

    await click(close_btn_selector);

    assert.dom(lightbox_open_selector).doesNotExist();

    openStub.restore();
  });

  test("handles close", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(trigger_selector);
    assert.dom(lightbox_open_selector).exists();

    await click(close_btn_selector);
    assert.dom(lightbox_open_selector).doesNotExist();
  });

  test("handles focus", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert.dom(lightbox_open_selector).doesNotExist();

    await click(trigger_selector);
    await waitForLoad();

    assert.dom(close_btn_selector).isFocused();

    // tab forward
    Array(50)
      .fill()
      .forEach(async () => {
        await triggerKeyEvent(lightbox_open_selector, "keyup", 9);
      });

    // it keeps focus inside the lightbox when tabbing forward
    assert.dom(lightbox_open_selector).exists();

    // tab backward
    Array(50)
      .fill()
      .forEach(async () => {
        await triggerKeyEvent(lightbox_open_selector, "keyup", 9, {
          shiftKey: true,
        });
      });

    // it keeps focus inside the lightbox when tabbing backward
    assert.dom(lightbox_open_selector).exists();

    await click(close_btn_selector);

    assert.dom(lightbox_open_selector).doesNotExist();

    // it restores focus in the main document when closed
    assert.dom(trigger_selector).isFocused();
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

    await click(trigger_selector);
    await waitForLoad();

    assert.dom(lightbox_open_selector).exists();

    assert.dom(".d-lightbox__screen-reader-announcer").exists();

    assert
      .dom(".d-lightbox__screen-reader-announcer")
      .hasText(firstExpectedTitle);

    await click(next_btn_selector);
    await waitForLoad();

    assert
      .dom(".d-lightbox__screen-reader-announcer")
      .hasText(secondExpectedTitle);

    await click(close_btn_selector);

    assert.dom(lightbox_open_selector).doesNotExist();
  });

  // TODO: this test is flaky on firefox. It runs fine locally and the functionality works in a real session, but fails on CI.
  chromeTest("handles keyboard shortcuts", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(trigger_selector);

    assert.dom(lightbox_open_selector).exists();

    await waitForLoad();

    await triggerKeyEvent(lightbox_open_selector, "keyup", "ArrowRight");

    assert.dom(counter_current_selector).hasText("2");

    await triggerKeyEvent(lightbox_open_selector, "keyup", "ArrowLeft");

    assert.dom(counter_current_selector).hasText("1");

    await triggerKeyEvent(lightbox_open_selector, "keyup", "ArrowDown");

    assert.dom(counter_current_selector).hasText("2");

    await triggerKeyEvent(lightbox_open_selector, "keyup", "ArrowUp");

    assert.dom(counter_current_selector).hasText("1");

    assert.dom(lightbox_selector).doesNotHaveClass("d-lightbox--is-zoomed");

    await triggerKeyEvent(lightbox_open_selector, "keyup", 90); // 'z' key

    assert.dom(lightbox_selector).hasClass("d-lightbox--is-zoomed");

    await triggerKeyEvent(lightbox_open_selector, "keyup", 90);

    assert.dom(lightbox_selector).doesNotHaveClass("d-lightbox--is-zoomed");
    assert.dom(lightbox_selector).doesNotHaveClass("d-lightbox--is-rotated");

    await triggerKeyEvent(lightbox_open_selector, "keyup", 82); // r key

    assert.dom(lightbox_selector).hasClass("d-lightbox--is-rotated");

    await triggerKeyEvent(lightbox_open_selector, "keyup", 82);
    await triggerKeyEvent(lightbox_open_selector, "keyup", 82);
    await triggerKeyEvent(lightbox_open_selector, "keyup", 82);

    // back to original rotation
    assert.dom(lightbox_selector).doesNotHaveClass("d-lightbox--is-rotated");

    assert.dom(carousel_selector).doesNotExist();

    await triggerKeyEvent(lightbox_open_selector, "keyup", 65); // 'a' key

    assert.dom(carousel_selector).exists();

    await triggerKeyEvent(lightbox_open_selector, "keyup", 65);

    assert.dom(carousel_selector).doesNotExist();

    assert
      .dom(lightbox_selector)
      .doesNotHaveClass("d-lightbox--has-expanded-title");

    await triggerKeyEvent(lightbox_open_selector, "keyup", 84); // 't' key

    assert.dom(lightbox_selector).hasClass("d-lightbox--has-expanded-title");

    await triggerKeyEvent(lightbox_open_selector, "keyup", 84);

    assert
      .dom(lightbox_selector)
      .doesNotHaveClass("d-lightbox--has-expanded-title");

    const requestFullscreenStub = sinon.stub(
      document.documentElement,
      "requestFullscreen"
    );

    assert.dom(lightbox_selector).doesNotHaveClass("d-lightbox--is-fullscreen");

    const exitFullscreenStub = sinon.stub(document, "exitFullscreen");

    await triggerKeyEvent(lightbox_open_selector, "keyup", 77); // 'm' key

    assert.dom(lightbox_selector).hasClass("d-lightbox--is-fullscreen");

    await triggerKeyEvent(lightbox_open_selector, "keyup", 77);

    assert.dom(lightbox_selector).doesNotHaveClass("d-lightbox--is-fullscreen");

    requestFullscreenStub.restore();
    exitFullscreenStub.restore();

    await triggerKeyEvent(lightbox_open_selector, "keyup", "Escape");

    assert.dom(lightbox_open_selector).doesNotExist();
  });
});

acceptance("Experimental Lightbox - carousel", function (needs) {
  needs.settings({ enable_experimental_lightbox: true });

  needs.pretender((server, helper) =>
    setupPretender(
      server,
      helper,
      multipleLargeImagesMarkup + multipleLargeImagesMarkup
    )
  );

  test("navigation", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(trigger_selector);

    // lightbox opens with the first image
    assert.dom(lightbox_open_selector).exists();
    assert.dom(counter_current_selector).hasText("1");

    // carousel is not visible by default
    assert.dom(carousel_selector).doesNotExist();

    await click(carousel_btn_selector);

    // carousel opens after clicking the button, and has prev/next buttons
    assert.dom(carousel_selector).exists();
    assert.dom(carousel_prev_btn_selector).exists();
    assert.dom(carousel_next_btn_selector).exists();

    // carousel has 5 items and an active item
    assert.dom(carousel_item_selector).exists({ count: 5 });
    assert.dom(carousel_item_selector + "--is-current").exists();

    await waitForLoad();

    // carousel current item is the first image
    assert
      .dom(carousel_item_selector + "--is-current")
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.first.smallURL);

    await click(carousel_next_btn_selector);
    await waitForLoad();

    // carousel next button works and current item is the second image
    assert
      .dom(carousel_item_selector + "--is-current")
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.second.smallURL);

    await click(carousel_prev_btn_selector);
    await waitForLoad();

    // carousel previous button works and current item is the first image again
    assert
      .dom(carousel_item_selector + "--is-current")
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.first.smallURL);

    await click(carousel_item_selector + ":nth-child(3)");
    await waitForLoad();

    // carousel manual item selection works and current item is the third image
    assert
      .dom(carousel_item_selector + "--is-current")
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.third.smallURL);

    // carousel closes after clicking the carousel button again
    await click(carousel_btn_selector);
    assert.dom(carousel_selector).doesNotExist();

    await click(close_btn_selector);
    assert.dom(lightbox_open_selector).doesNotExist();
  });

  test("arrows are not shown when there are only a few images", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const lightboxes = [...queryAll(trigger_selector)];

    const lastThreeLightboxes = lightboxes.slice(-3);

    lastThreeLightboxes.forEach((lightbox) => {
      lightbox.remove();
    });

    await click(trigger_selector);
    assert.dom(lightbox_selector).exists();
    assert.dom(carousel_selector).doesNotExist();

    // carousel opens after clicking the button
    await click(carousel_btn_selector);
    assert.dom(carousel_selector).exists();
    assert.dom(carousel_item_selector).exists({ count: 2 });

    // no prev/next buttons when carousel only has a few images
    assert.dom(carousel_prev_btn_selector).doesNotExist();
    assert.dom(carousel_next_btn_selector).doesNotExist();

    // carousel closes after clicking the button again
    await click(carousel_btn_selector);
    assert.dom(carousel_selector).doesNotExist();

    await click(close_btn_selector);
    assert.dom(lightbox_open_selector).doesNotExist();
  });
});

acceptance("Experimental Lightbox - mobile", function (needs) {
  needs.settings({ enable_experimental_lightbox: true });

  needs.pretender((server, helper) =>
    setupPretender(server, helper, multipleLargeImagesMarkup)
  );

  test("navigation - swipe navigation LTR", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(trigger_selector);

    assert.dom(lightbox_open_selector).exists();
    assert.dom(counter_current_selector).hasText("1");

    await triggerEvent(lightbox_body_selector, "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ screenX: 0, screenY: 0 }],
    });

    await triggerEvent(lightbox_body_selector, "touchend", {
      changedTouches: [{ screenX: 150, screenY: 0 }],
      touches: [{ pageX: 150, pageY: 0 }],
    });

    // swiping left goes to the previous image
    assert.dom(counter_current_selector).hasText("3");

    await triggerEvent(lightbox_body_selector, "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ screenX: 0, screenY: 0 }],
    });

    await triggerEvent(lightbox_body_selector, "touchend", {
      changedTouches: [{ screenX: -150, screenY: 0 }],
      touches: [{ pageX: 150, pageY: 0 }],
    });

    // swiping right goes to the next image
    assert.dom(counter_current_selector).hasText("1");

    await click(close_btn_selector);
    assert.dom(lightbox_open_selector).doesNotExist();
  });

  test("navigation - swipe navigation RTL", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(trigger_selector);

    assert.dom(lightbox_open_selector).exists();
    assert.dom(counter_current_selector).hasText("1");

    const containsStub = sinon.stub(
      document.documentElement.classList,
      "contains"
    );

    containsStub.withArgs("rtl").returns(true);

    await triggerEvent(lightbox_body_selector, "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ screenX: 0, screenY: 0 }],
    });

    await triggerEvent(lightbox_body_selector, "touchend", {
      changedTouches: [{ screenX: -150, screenY: 0 }],
      touches: [{ pageX: 150, pageY: 0 }],
    });

    // swiping left goes to the next image in RTL
    assert.dom(counter_current_selector).hasText("2");

    await triggerEvent(lightbox_body_selector, "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ screenX: 0, screenY: 0 }],
    });

    await triggerEvent(lightbox_body_selector, "touchend", {
      changedTouches: [{ screenX: 150, screenY: 0 }],
      touches: [{ pageX: 150, pageY: 0 }],
    });

    // swiping right goes to the previous image in RTL
    assert.dom(counter_current_selector).hasText("1");

    containsStub.restore();

    await click(close_btn_selector);
    assert.dom(lightbox_open_selector).doesNotExist();
  });

  test("navigation - swipe close", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(trigger_selector);
    assert.dom(lightbox_open_selector).exists();

    await triggerEvent(lightbox_body_selector, "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ screenX: 0, screenY: 0 }],
    });

    await triggerEvent(lightbox_body_selector, "touchend", {
      changedTouches: [{ screenX: 0, screenY: -150 }],
      touches: [{ pageX: 0, pageY: 150 }],
    });

    assert.dom(lightbox_open_selector).doesNotExist();
  });

  test("navigation - swipe carousel", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(trigger_selector);
    assert.dom(lightbox_open_selector).exists();
    assert.dom(carousel_selector).doesNotExist();

    await triggerEvent(lightbox_body_selector, "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ screenX: 0, screenY: 0 }],
    });

    await triggerEvent(lightbox_body_selector, "touchend", {
      changedTouches: [{ screenX: 0, screenY: 150 }],
      touches: [{ pageX: 0, pageY: 150 }],
    });

    assert.dom(carousel_selector).exists(); // opens after swiping down

    await triggerEvent(lightbox_body_selector, "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ screenX: 0, screenY: 0 }],
    });

    await triggerEvent(lightbox_body_selector, "touchend", {
      changedTouches: [{ screenX: 0, screenY: 150 }],
      touches: [{ pageX: 0, pageY: 150 }],
    });

    assert.dom(carousel_selector).doesNotExist(); // closes after swiping down again

    await click(close_btn_selector);
    assert.dom(lightbox_open_selector).doesNotExist();
  });
});

acceptance("Experimental Lightbox - loading state", function (needs) {
  needs.settings({ enable_experimental_lightbox: true });

  needs.pretender((server, helper) =>
    setupPretender(server, helper, markupWithInvalidImage)
  );

  test("handles loading errors", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(trigger_selector);
    assert.dom(lightbox_open_selector).exists();

    await waitForLoad();

    // the image has the correct src
    assert
      .dom(main_img_selector)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL);

    await click(next_btn_selector);

    // does not show an image if it can't be loaded
    assert.dom(main_img_selector).doesNotExist();

    await click(next_btn_selector);

    // it shows the correct image when navigating after an error
    assert.dom(counter_current_selector).hasText("3");

    await waitForLoad();

    assert
      .dom(main_img_selector)
      .hasAttribute("src", LIGHTBOX_IMAGE_FIXTURES.second.fullsizeURL);

    await click(close_btn_selector);
    assert.dom(lightbox_open_selector).doesNotExist();
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

  test("it doesn't show the newtab and download buttons to anons if prevent_anons_from_downloading_files is enabled", async function (assert) {
    this.siteSettings.prevent_anons_from_downloading_files = true;
    await visit("/t/internationalization-localization/280");
    await click(trigger_selector);

    // it doesn not show the newtab or download button
    assert.dom(new_tab_btn_selector).doesNotExist();
    assert.dom(download_btn_selector).doesNotExist();
  });

  test("it doesn't show the zoom button if the image is smaller than the viewport", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(trigger_selector);
    assert.dom(zoom_btn_selector).doesNotExist();

    await click(close_btn_selector);
    assert.dom(lightbox_open_selector).doesNotExist();
  });
});
