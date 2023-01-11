import {
  LIGHTBOX_IMAGE_FIXTURES,
  generateLightboxMarkup,
} from "discourse/tests/helpers/lightbox-helpers";
import {
  acceptance,
  chromeTest,
  exists,
  query,
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

const selector = ".lightbox";

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
    await click(selector);

    assert.notOk(
      exists("[data-lightbox-content]"),
      "it doesn't interfere with magnific when the setting is disabled"
    );

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
    await click(selector);

    assert.ok(
      exists("[data-lightbox-content]"),
      "it opens the lightbox when the setting is enabled"
    );

    await waitForLoad();

    assert.ok(exists("[data-lightbox-title]"), "title is visible");

    assert.strictEqual(
      query("[data-lightbox-title-text]").textContent,
      LIGHTBOX_IMAGE_FIXTURES.first.title,
      "title is correct"
    );

    assert.strictEqual(
      query("[data-lightbox-file-details]").textContent,
      LIGHTBOX_IMAGE_FIXTURES.first.fileDetails,
      "file details are correct"
    );

    assert.ok(
      exists("[data-lightbox-close-button]"),
      "close button is visible"
    );

    assert.strictEqual(
      document.activeElement,
      query("[data-lightbox-close-button]"),
      "close button is focused when the lightbox is opened"
    );

    assert.ok(
      exists("[data-lightbox-newtab-button]"),
      "download button is visible"
    );

    assert.ok(
      exists("[data-lightbox-fullscreen-button]"),
      "fullscreen button is visible"
    );

    assert.ok(
      exists("[data-lightbox-rotate-button]"),
      "rotate button is visible"
    );

    assert.ok(
      exists("[data-lightbox-zoom-button]"),
      "zoom in button is visible"
    );

    assert.ok(
      exists("[data-lightbox-download-button]"),
      "download button is visible"
    );

    assert.notOk(
      exists("[data-lightbox-previous-button]"),
      "previous button is not visible if there's only one image"
    );

    assert.notOk(
      exists("[data-lightbox-next-button]"),
      "next button is not visible if there's only one image"
    );

    assert.notOk(
      exists("[data-lightbox-multi-item-controls]"),
      "multi item controls are not visible if there's only one image"
    );

    assert.notOk(
      exists("[data-lightbox-carousel]"),
      "carousel is not visible if there's only one image"
    );

    assert.notOk(
      exists("[data-lightbox-error-message]"),
      "error message is not visible"
    );

    assert.ok(exists("[data-lightbox-main-image]"), "main image is visible");

    assert.ok(
      query("[data-lightbox-main-image]").hasAttribute("src"),
      "main image has a src attribute"
    );

    assert.strictEqual(
      query("[data-lightbox-main-image]").getAttribute("src"),
      LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL,
      "main image src is correct"
    );

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-fullscreen"
      ),
      "lightbox is not fullscreen by default"
    );

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-rotated"
      ),
      "lightbox is not rotated by default"
    );

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-zoomed"
      ),
      "lightbox is not zoomed by default"
    );

    assert.ok(
      exists("[data-lightbox-backdrop]"),
      "lightbox backdrop is visible"
    );

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");
  });
});

acceptance("Experimental Lightbox - layout multiple images", function (needs) {
  needs.settings({ enable_experimental_lightbox: true });

  needs.pretender((server, helper) =>
    setupPretender(server, helper, multipleLargeImagesMarkup)
  );

  test("it shows multiple image controls when there's more than one item", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(selector);

    await waitForLoad();

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    assert.ok(
      exists("[data-lightbox-previous-button]"),
      "previous button is visible"
    );

    assert.ok(exists("[data-lightbox-next-button]"), "next button is visible");

    assert.ok(
      exists("[data-lightbox-multi-item-controls]"),
      "multi item controls are visible"
    );

    assert.ok(exists("[data-lightbox-counter]"), "counter is visible");

    assert.strictEqual(
      query("[data-lightbox-counter-current]").textContent,
      "1",
      "counter current is correct"
    );

    assert.strictEqual(
      query("[data-lightbox-counter-total]").textContent,
      "3",
      "counter total is correct"
    );

    assert.notOk(
      exists("[data-lightbox-carousel]"),
      "carousel is not visible by default"
    );

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");
  });
});

acceptance("Experimental Lightbox - interaction", function (needs) {
  needs.settings({ enable_experimental_lightbox: true });

  needs.pretender((server, helper) =>
    setupPretender(server, helper, multipleLargeImagesMarkup)
  );

  test("handles zoom", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(selector);

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    await waitForLoad();

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-zoomed"
      ),
      "lightbox is not zoomed by default"
    );

    await click("[data-lightbox-zoom-button]");

    assert.ok(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-zoomed"
      ),
      "zoom button toggles zoom"
    );

    assert.notOk(
      exists("[data-lightbox-title-text]"),
      "title is not shown when zoomed"
    );

    await click("[data-lightbox-zoom-button]");

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-zoomed"
      ),
      "clicking zoom button again exists zoom"
    );

    assert.ok(
      exists("[data-lightbox-title-text]"),
      "title is restored after exiting zoom"
    );

    await click("[data-lightbox-main-image]");

    assert.ok(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-zoomed"
      ),
      "clicking main image toggles zoom"
    );

    await click("[data-lightbox-zoomed-image-container]");

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-zoomed"
      ),
      "clicking zoomed image exists zoom"
    );

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");
  });

  test("handles rotation", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(selector);

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    await waitForLoad();

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-rotated"
      ),
      "lightbox is not rotated by default"
    );

    await click("[data-lightbox-rotate-button]");

    assert.ok(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-rotated"
      ),
      "lightbox is rotated"
    );

    assert.ok(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-rotated-90"
      ),
      "lightbox is rotated 90 degrees after first click"
    );

    await click("[data-lightbox-rotate-button]");

    assert.ok(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-rotated-180"
      ),
      "lightbox is rotated 180 degrees after second click"
    );

    await click("[data-lightbox-rotate-button]");

    assert.ok(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-rotated-270"
      ),
      "lightbox is rotated 270 degrees after third click"
    );

    await click("[data-lightbox-rotate-button]");

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-rotated"
      ),
      "lightbox is not rotated and resets after fourth click"
    );

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");
  });

  test("handles navigation - next", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(selector);

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    assert.strictEqual(
      query("[data-lightbox-counter-current]").textContent,
      "1",
      "starts at 1"
    );

    assert.strictEqual(
      query("[data-lightbox-counter-total]").textContent,
      "3",
      "has a total of 3"
    );

    await waitForLoad();

    assert.strictEqual(
      query("[data-lightbox-main-image]").getAttribute("src"),
      LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL,
      "shows the first image"
    );

    await click("[data-lightbox-next-button]");

    await waitForLoad();

    assert.strictEqual(
      query("[data-lightbox-counter-current]").textContent,
      "2",
      "increments counter to 2"
    );

    assert.strictEqual(
      query("[data-lightbox-main-image]").getAttribute("src"),
      LIGHTBOX_IMAGE_FIXTURES.second.fullsizeURL,
      "shows the second image"
    );

    await click("[data-lightbox-next-button]");

    await waitForLoad();

    assert.strictEqual(
      query("[data-lightbox-counter-current]").textContent,
      "3",
      "increments counter to 3"
    );

    assert.strictEqual(
      query("[data-lightbox-main-image]").getAttribute("src"),
      LIGHTBOX_IMAGE_FIXTURES.third.fullsizeURL,
      "shows the third image"
    );

    await click("[data-lightbox-next-button]");

    await waitForLoad();

    assert.strictEqual(
      query("[data-lightbox-counter-current]").textContent,
      "1",
      "loops counter back to 1"
    );

    assert.strictEqual(
      query("[data-lightbox-main-image]").getAttribute("src"),
      LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL,
      "shows the first image again"
    );

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");
  });

  test("handles navigation - previous", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(selector);

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    assert.strictEqual(
      query("[data-lightbox-counter-current]").textContent,
      "1",
      "starts at 1"
    );

    assert.strictEqual(
      query("[data-lightbox-counter-total]").textContent,
      "3",
      "has a total of 3"
    );

    await waitForLoad();

    assert.strictEqual(
      query("[data-lightbox-main-image]").getAttribute("src"),
      LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL,
      "shows the first image"
    );

    await click("[data-lightbox-previous-button]");

    assert.strictEqual(
      query("[data-lightbox-counter-current]").textContent,
      "3",
      "loops counter back to 3"
    );

    await waitForLoad();

    assert.strictEqual(
      query("[data-lightbox-main-image]").getAttribute("src"),
      LIGHTBOX_IMAGE_FIXTURES.third.fullsizeURL,
      "shows the third image"
    );

    await click("[data-lightbox-previous-button]");

    assert.strictEqual(
      query("[data-lightbox-counter-current]").textContent,
      "2",
      "decrements counter to 2"
    );

    await waitForLoad();

    assert.strictEqual(
      query("[data-lightbox-main-image]").getAttribute("src"),
      LIGHTBOX_IMAGE_FIXTURES.second.fullsizeURL,
      "shows the second image"
    );

    await click("[data-lightbox-previous-button]");

    assert.strictEqual(
      query("[data-lightbox-counter-current]").textContent,
      "1",
      "decrements counter to 1"
    );

    await waitForLoad();

    assert.strictEqual(
      query("[data-lightbox-main-image]").getAttribute("src"),
      LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL,
      "shows the first image again"
    );

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");
  });

  test("handles navigation - opens at the correct index", async function (assert) {
    await visit("/t/internationalization-localization/280");
    const lightboxes = queryAll(selector);

    await click(lightboxes[1]);

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    assert.strictEqual(
      query("[data-lightbox-counter-current]").textContent,
      "2",
      "starts at 2"
    );

    assert.strictEqual(
      query("[data-lightbox-counter-total]").textContent,
      "3",
      "has a total of 3"
    );

    await waitForLoad();

    assert.strictEqual(
      query("[data-lightbox-main-image]").getAttribute("src"),
      LIGHTBOX_IMAGE_FIXTURES.second.fullsizeURL,
      "shows the second image"
    );

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");

    await click(lightboxes[2]);

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    assert.strictEqual(
      query("[data-lightbox-counter-current]").textContent,
      "3",
      "starts at 3"
    );

    assert.strictEqual(
      query("[data-lightbox-counter-total]").textContent,
      "3",
      "has a total of 3"
    );

    await waitForLoad();

    assert.strictEqual(
      query("[data-lightbox-main-image]").getAttribute("src"),
      LIGHTBOX_IMAGE_FIXTURES.third.fullsizeURL,
      "shows the third image"
    );

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");
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

    await click(selector);

    await waitForLoad();

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    assert.ok(
      classListAddStub.calledWith("has-lightbox"),
      "adds has-lightbox class to document element"
    );

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");

    assert.ok(
      classListRemoveStub.calledWith("has-lightbox"),
      "removes has-lightbox class from document element"
    );

    classListAddStub.restore();
    classListRemoveStub.restore();
  });

  test("handles fullscreen", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(selector);

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-fullscreen"
      ),
      "it is not fullscreen by default"
    );

    const requestFullscreenStub = sinon.stub(
      document.documentElement,
      "requestFullscreen"
    );

    const exitFullscreenStub = sinon.stub(document, "exitFullscreen");

    await click("[data-lightbox-fullscreen-button]");

    assert.ok(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-fullscreen"
      ),
      "it is fullscreen"
    );

    assert.ok(requestFullscreenStub.calledOnce, "it calls requestFullscreen");

    await click("[data-lightbox-fullscreen-button]");

    assert.notOk(
      query("[data-lightbox-content]").classList.contains(
        "d-lightbox--is-fullscreen"
      ),
      "it is not fullscreen"
    );

    assert.ok(exitFullscreenStub.calledOnce, "it calls exitFullscreen");

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");

    requestFullscreenStub.restore();
    exitFullscreenStub.restore();
  });

  test("handles download", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(selector);

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    const clickStub = sinon.stub(HTMLAnchorElement.prototype, "click");

    // appends and clicks <a download="..." href="..."></a>
    await click("[data-lightbox-download-button]");

    assert.ok(clickStub.called, "The click method was called");

    await click("[data-lightbox-close-button]");
    assert.notOk(exists("[data-lightbox-content]"), "it closes");

    clickStub.restore();
  });

  test("handles newtab", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(selector);

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    const openStub = sinon.stub(window, "open");

    await click("[data-lightbox-newtab-button]");

    assert.ok(openStub.called, "The open method was called");

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");

    openStub.restore();
  });

  test("handles close", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(selector);

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");
  });

  test("handles focus", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert.notOk(
      document.activeElement.closest("[data-lightbox-content]"),
      "it is not focused"
    );

    const lightbox = query(selector);

    await click(lightbox);

    await waitForLoad();

    assert.ok(
      document.activeElement === query("[data-lightbox-close-button]"),
      "it focuses the close button when opened"
    );

    // tab forward
    Array(50)
      .fill()
      .forEach(async () => {
        await triggerKeyEvent("[data-lightbox-content]", "keyup", 9);
      });

    assert.ok(
      document.activeElement.closest("[data-lightbox-content]"),
      "it keeps focus inside the lightbox when tabbing forward"
    );

    // tab backward
    Array(50)
      .fill()
      .forEach(async () => {
        await triggerKeyEvent("[data-lightbox-content]", "keyup", 9, {
          shiftKey: true,
        });
      });

    assert.ok(
      document.activeElement.closest("[data-lightbox-content]"),
      "it keeps focus inside the lightbox when tabbing backward"
    );

    await click("[data-lightbox-close-button]");

    assert.notOk(
      document.activeElement.closest("[data-lightbox-content]"),
      "it is not focused"
    );

    assert.ok(
      document.activeElement === lightbox,
      "it restores focus in the main document when closed"
    );
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

    await click(selector);

    await waitForLoad();

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    assert.ok(
      exists("[data-lightbox-screen-reader-announcer]"),
      "it has a screen reader announcer"
    );

    assert.strictEqual(
      query("[data-lightbox-screen-reader-announcer]").textContent.trim(),
      firstExpectedTitle,
      "it updates the screen reader announcer when navigating"
    );

    await click("[data-lightbox-next-button]");

    await waitForLoad();

    assert.strictEqual(
      query("[data-lightbox-screen-reader-announcer]").textContent.trim(),
      secondExpectedTitle,
      "it updates the screen reader announcer when navigating"
    );

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");
  });

  // TODO: this test is flaky on firefox. It runs fine locally and the functionality works in a real session, but fails on CI.
  chromeTest("handles keyboard shortcuts", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(selector);

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    await waitForLoad();

    await triggerKeyEvent("[data-lightbox-content]", "keyup", "ArrowRight");

    assert.strictEqual(
      query("[data-lightbox-counter-current]").textContent,
      "2",
      "ArrowRight increments counter to 2"
    );

    await triggerKeyEvent("[data-lightbox-content]", "keyup", "ArrowLeft");

    assert.strictEqual(
      query("[data-lightbox-counter-current]").textContent,
      "1",
      "ArrowLeft decrements counter to 1"
    );

    await triggerKeyEvent("[data-lightbox-content]", "keyup", "ArrowDown");

    assert.strictEqual(
      query("[data-lightbox-counter-current]").textContent,
      "2",
      "ArrowDown increments counter to 2"
    );

    await triggerKeyEvent("[data-lightbox-content]", "keyup", "ArrowUp");

    assert.strictEqual(
      query("[data-lightbox-counter-current]").textContent,
      "1",
      "ArrowUp decrements counter to 1"
    );

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-zoomed"
      ),
      "is not zoomed"
    );

    await triggerKeyEvent("[data-lightbox-content]", "keyup", 90);

    assert.ok(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-zoomed"
      ),
      "pressing 'z' toggles zoom"
    );

    await triggerKeyEvent("[data-lightbox-content]", "keyup", 90);

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-zoomed"
      ),
      "pressing 'z' again exits zoom"
    );

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-rotated"
      ),
      "is not rotated"
    );

    await triggerKeyEvent("[data-lightbox-content]", "keyup", 82);

    assert.ok(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-rotated"
      ),
      "pressing 'r' toggles rotation"
    );

    await triggerKeyEvent("[data-lightbox-content]", "keyup", 82);
    await triggerKeyEvent("[data-lightbox-content]", "keyup", 82);
    await triggerKeyEvent("[data-lightbox-content]", "keyup", 82);

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-rotated"
      ),
      "pressing 'r' 3 more times results in no rotation 90|180|270"
    );

    assert.notOk(exists("[data-lightbox-carousel]"), "carousel is not visible");

    await triggerKeyEvent("[data-lightbox-content]", "keyup", 65);

    assert.ok(
      exists("[data-lightbox-carousel]"),
      "pressing 'a' toggles carousel"
    );

    await triggerKeyEvent("[data-lightbox-content]", "keyup", 65);

    assert.notOk(
      exists("[data-lightbox-carousel]"),
      "pressing 'a' again hides carousel"
    );

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--has-expanded-title"
      ),
      "title is not expanded by default"
    );

    await triggerKeyEvent("[data-lightbox-content]", "keyup", 84);

    assert.ok(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--has-expanded-title"
      ),
      "pressing 't' toggles title"
    );

    await triggerKeyEvent("[data-lightbox-content]", "keyup", 84);

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--has-expanded-title"
      ),
      "pressing 't' again hides title"
    );

    const requestFullscreenStub = sinon.stub(
      document.documentElement,
      "requestFullscreen"
    );

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-fullscreen"
      ),
      "is not fullscreen"
    );

    const exitFullscreenStub = sinon.stub(document, "exitFullscreen");

    await triggerKeyEvent("[data-lightbox-content]", "keyup", 77);

    assert.ok(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-fullscreen"
      ),
      "pressing 'm' toggles fullscreen"
    );

    await triggerKeyEvent("[data-lightbox-content]", "keyup", 77);

    assert.notOk(
      query("[data-lightbox-element]").classList.contains(
        "d-lightbox--is-fullscreen"
      ),
      "pressing 'm' again exits fullscreen"
    );

    requestFullscreenStub.restore();
    exitFullscreenStub.restore();

    await triggerKeyEvent("[data-lightbox-content]", "keyup", "Escape");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");
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
    await click(selector);

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    assert.strictEqual(
      query("[data-lightbox-counter-current]").textContent,
      "1",
      "starts at 1"
    );

    assert.strictEqual(
      exists("[data-lightbox-carousel]"),
      false,
      "carousel is not visible by default"
    );

    await click("[data-lightbox-carousel-button]");

    assert.strictEqual(
      exists("[data-lightbox-carousel]"),
      true,
      "carousel opens after clicking the button"
    );

    assert.strictEqual(
      exists("[data-lightbox-carousel-previous-button]"),
      true,
      "carousel has a previous button"
    );

    assert.strictEqual(
      exists("[data-lightbox-carousel-next-button]"),
      true,
      "carousel has a next button"
    );

    assert.strictEqual(
      queryAll("[data-lightbox-carousel-item]").length,
      6,
      "carousel has 6 items"
    );

    assert.strictEqual(
      exists("[data-lightbox-carousel-item].active"),
      true,
      "carousel has a current item"
    );

    await waitForLoad();

    assert.strictEqual(
      query("[data-lightbox-carousel-item].active").getAttribute("src"),
      LIGHTBOX_IMAGE_FIXTURES.first.smallURL,
      "carousel current item is the first image"
    );

    await click("[data-lightbox-carousel-next-button]");

    await waitForLoad();

    assert.strictEqual(
      query("[data-lightbox-carousel-item].active").getAttribute("src"),
      LIGHTBOX_IMAGE_FIXTURES.second.smallURL,
      "carousel next button works and current item is the second image"
    );

    await click("[data-lightbox-carousel-previous-button]");

    await waitForLoad();

    assert.strictEqual(
      query("[data-lightbox-carousel-item].active").getAttribute("src"),
      LIGHTBOX_IMAGE_FIXTURES.first.smallURL,
      "carousel previous button works and current item is the first image again"
    );

    await click("[data-lightbox-carousel-item]:nth-child(3)");

    await waitForLoad();

    assert.strictEqual(
      query("[data-lightbox-carousel-item].active").getAttribute("src"),
      LIGHTBOX_IMAGE_FIXTURES.third.smallURL,
      "carousel manual item selection works and current item is the third image"
    );

    await click("[data-lightbox-carousel-button]");

    assert.strictEqual(
      exists("[data-lightbox-carousel]"),
      false,
      "carousel closes after clicking the carousel button again"
    );

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");
  });

  test("arrows are not shown when there are only a few images", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const lightboxes = [...queryAll(selector)];

    const lastThreeLightboxes = lightboxes.slice(-3);

    lastThreeLightboxes.forEach((lightbox) => {
      lightbox.remove();
    });

    await click(selector);

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    assert.strictEqual(
      exists("[data-lightbox-carousel]"),
      false,
      "carousel is not visible by default"
    );

    await click("[data-lightbox-carousel-button]");

    assert.strictEqual(
      exists("[data-lightbox-carousel]"),
      true,
      "carousel opens after clicking the button"
    );

    assert.strictEqual(
      queryAll("[data-lightbox-carousel-item]").length,
      3,
      "carousel has 3 items"
    );

    assert.notOk(
      exists("[data-lightbox-carousel-previous-button]"),
      "carousel doesn't have a previous button when it only has a few images"
    );

    assert.notOk(
      exists("[data-lightbox-carousel-next-button]"),
      "carousel doesn't have a previous button when it only has a few images"
    );

    await click("[data-lightbox-carousel-button]");

    assert.strictEqual(
      exists("[data-lightbox-carousel]"),
      false,
      "carousel closes after clicking the button again"
    );

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");
  });
});

acceptance("Experimental Lightbox - mobile", function (needs) {
  needs.settings({ enable_experimental_lightbox: true });

  needs.pretender((server, helper) =>
    setupPretender(server, helper, multipleLargeImagesMarkup)
  );

  test("navigation - swipe navigation LTR", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(selector);

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    assert.strictEqual(
      query("[data-lightbox-counter-current]").innerText,
      "1",
      "it starts at the first image"
    );

    await triggerEvent("[data-lightbox-body]", "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ screenX: 0, screenY: 0 }],
    });

    await triggerEvent("[data-lightbox-body]", "touchend", {
      changedTouches: [{ screenX: 150, screenY: 0 }],
      touches: [{ pageX: 150, pageY: 0 }],
    });

    assert.strictEqual(
      query("[data-lightbox-counter-current]").innerText,
      "3",
      "swiping left goes to the previous image"
    );

    await triggerEvent("[data-lightbox-body]", "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ screenX: 0, screenY: 0 }],
    });

    await triggerEvent("[data-lightbox-body]", "touchend", {
      changedTouches: [{ screenX: -150, screenY: 0 }],
      touches: [{ pageX: 150, pageY: 0 }],
    });

    assert.strictEqual(
      query("[data-lightbox-counter-current]").innerText,
      "1",
      "swiping right goes to the next image"
    );

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");
  });

  test("navigation - swipe navigation RTL", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(selector);

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    assert.strictEqual(
      query("[data-lightbox-counter-current]").innerText,
      "1",
      "it starts at the first image"
    );

    const containsStub = sinon.stub(
      document.documentElement.classList,
      "contains"
    );

    containsStub.withArgs("rtl").returns(true);

    await triggerEvent("[data-lightbox-body]", "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ screenX: 0, screenY: 0 }],
    });

    await triggerEvent("[data-lightbox-body]", "touchend", {
      changedTouches: [{ screenX: -150, screenY: 0 }],
      touches: [{ pageX: 150, pageY: 0 }],
    });

    assert.strictEqual(
      query("[data-lightbox-counter-current]").innerText,
      "2",
      "swiping left goes to the next image in RTL"
    );

    await triggerEvent("[data-lightbox-body]", "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ screenX: 0, screenY: 0 }],
    });

    await triggerEvent("[data-lightbox-body]", "touchend", {
      changedTouches: [{ screenX: 150, screenY: 0 }],
      touches: [{ pageX: 150, pageY: 0 }],
    });

    assert.strictEqual(
      query("[data-lightbox-counter-current]").innerText,
      "1",
      "swiping right goes to the previous image in RTL"
    );

    containsStub.restore();

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");
  });

  test("navigation - swipe close", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(selector);

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    await triggerEvent("[data-lightbox-body]", "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ screenX: 0, screenY: 0 }],
    });

    await triggerEvent("[data-lightbox-body]", "touchend", {
      changedTouches: [{ screenX: 0, screenY: -150 }],
      touches: [{ pageX: 0, pageY: 150 }],
    });

    assert.notOk(exists("[data-lightbox-content]"), "it closes");
  });

  test("navigation - swipe carousel", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(selector);

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    assert.notOk(
      exists("[data-lightbox-carousel]"),
      "carousel is not visible by default"
    );

    await triggerEvent("[data-lightbox-body]", "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ screenX: 0, screenY: 0 }],
    });

    await triggerEvent("[data-lightbox-body]", "touchend", {
      changedTouches: [{ screenX: 0, screenY: 150 }],
      touches: [{ pageX: 0, pageY: 150 }],
    });

    assert.ok(
      exists("[data-lightbox-carousel]"),
      "carousel opens after swiping down"
    );

    await triggerEvent("[data-lightbox-body]", "touchstart", {
      changedTouches: [{ screenX: 0, screenY: 0 }],
      touches: [{ screenX: 0, screenY: 0 }],
    });

    await triggerEvent("[data-lightbox-body]", "touchend", {
      changedTouches: [{ screenX: 0, screenY: 150 }],
      touches: [{ pageX: 0, pageY: 150 }],
    });

    assert.notOk(
      exists("[data-lightbox-carousel]"),
      "carousel closes after swiping down again"
    );

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");
  });
});

acceptance("Experimental Lightbox - loading state", function (needs) {
  needs.settings({ enable_experimental_lightbox: true });

  needs.pretender((server, helper) =>
    setupPretender(server, helper, markupWithInvalidImage)
  );

  test("handles loading errors", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(selector);

    assert.ok(exists("[data-lightbox-content]"), "it opens");

    await waitForLoad();

    assert.strictEqual(
      query("[data-lightbox-main-image]").src,
      LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL,
      "the image has the correct src"
    );

    await click("[data-lightbox-next-button]");

    assert.notOk(
      exists("[data-lightbox-main-image]"),
      true,
      "the does not show an image if it can't be loaded"
    );

    await click("[data-lightbox-next-button]");

    assert.strictEqual(
      query("[data-lightbox-counter-current").textContent,
      "3",
      "it shows the correct image when navigating after an error"
    );

    await waitForLoad();

    assert.strictEqual(
      query("[data-lightbox-main-image]").src,
      LIGHTBOX_IMAGE_FIXTURES.second.fullsizeURL,
      "the image has the correct src"
    );

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");
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

    await click(selector);

    assert.notOk(
      exists("[data-lightbox-newtab-button]"),
      "it doesn't show the newtab button"
    );

    assert.notOk(
      exists("[data-lightbox-download-button]"),
      "it doesn't show the download button"
    );
  });

  test("it doesn't show the zoom button if the image is smaller than the viewport", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(selector);

    assert.notOk(
      exists("[data-lightbox-zoom-button]"),
      "it doesn't show the zoom button"
    );

    await click("[data-lightbox-close-button]");

    assert.notOk(exists("[data-lightbox-content]"), "it closes");
  });
});
