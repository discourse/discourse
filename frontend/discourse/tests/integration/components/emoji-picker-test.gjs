import {
  click,
  fillIn,
  findAll,
  focus,
  render,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { IMAGE_VERSION as v } from "pretty-text/emoji/version";
import { module, test } from "qunit";
import sinon from "sinon";
import EmojiPicker from "discourse/components/emoji-picker";
import Content from "discourse/components/emoji-picker/content";
import { SKIN_TONE_STORE_KEY } from "discourse/services/emoji-store";
import emojisFixtures from "discourse/tests/fixtures/emojis-fixtures";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import emojiPicker from "discourse/tests/helpers/emoji-picker-helper";
import { i18n } from "discourse-i18n";

const TONE = ".emoji-picker__diversity-trigger";
const TONE_NAMES = {
  1: "default_tone",
  2: "light_tone",
  3: "medium_light_tone",
  4: "medium_tone",
  5: "medium_dark_tone",
  6: "dark_tone",
};

function toneName(scale) {
  return i18n(`emoji_picker.${TONE_NAMES[scale]}`);
}

function clapUrl(scale) {
  const path = scale === 1 ? "clap" : `clap/${scale}`;
  return `/images/emoji/twitter/${path}.png?v=${v}`;
}

module("Integration | Component | EmojiPickerContent", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/emojis.json", () =>
      response(emojisFixtures["/emojis.json"])
    );

    pretender.get("/emojis/search-aliases.json", () => {
      return response([]);
    });

    this.emojiStore = this.container.lookup("service:emoji-store");
  });

  hooks.afterEach(function () {
    this.emojiStore.diversity = 1;
  });

  test("When displaying navigation", async function (assert) {
    await render(<template><Content /></template>);

    assert
      .dom(`.emoji-picker__section-btn.active[data-section="favorites"]`)
      .exists("it renders favorites section");
    assert
      .dom(`.emoji-picker__section-btn[data-section="smileys_&_emotion"]`)
      .exists();
    assert
      .dom(`.emoji-picker__section-btn[data-section="people_&_body"]`)
      .exists();
    assert.dom(`.emoji-picker__section-btn[data-section="objects"]`).exists();
  });

  test("When changing tone scale", async function (assert) {
    await render(<template><Content /></template>);
    await emojiPicker(".emoji-picker").tone(6);

    assert
      .dom(`img[src="/images/emoji/twitter/raised_hands/6.png?v=${v}"]`)
      .exists("it applies the tone to emojis");
    assert
      .dom(".emoji-picker__diversity-trigger img[title='clap:t6']")
      .exists("it changes the current scale to t6");
    assert
      .dom(
        `.emoji-picker__section-btn img[src="/images/emoji/twitter/raised_hands/6.png?v=${v}"]`
      )
      .exists("it applies the tone to the section selector");
  });

  test("When requesting section", async function (assert) {
    await render(<template><Content /></template>);

    assert.strictEqual(
      document.querySelector("#ember-testing-container").scrollTop,
      0
    );

    await click(`.emoji-picker__section-btn[data-section="objects"]`);

    assert.true(
      document.querySelector(".emoji-picker__scrollable-content").scrollTop > 0,
      "it scrolls to the section"
    );
  });

  test("When filtering emojis", async function (assert) {
    await render(<template><Content /></template>);
    await fillIn(".filter-input", "grin");

    assert
      .dom(".emoji-picker__section.filtered > img")
      .exists({ count: 5 }, "it filters the emojis list");
    assert
      .dom('.emoji-picker__section.filtered > img[alt="grinning_face"]')
      .exists("it filters the correct emoji");

    await fillIn(".filter-input", "Grinning");

    assert
      .dom('.emoji-picker__section.filtered > img[alt="grinning_face"]')
      .exists("it is case insensitive");

    await fillIn(".filter-input", "grinning");

    assert
      .dom('.emoji-picker__section.filtered > img[alt="grinning_face"]')
      .exists("it filters the correct emoji using search alias");

    await emojiPicker(".emoji-picker").tone(2);
    await fillIn(".filter-input", "fist");

    assert
      .dom(
        `.emoji-picker__section.filtered > img[src="/images/emoji/twitter/raised_fist/2.png?v=${v}"]`
      )
      .exists("it uses the selected skin tone in search results");
  });

  test("When selecting an emoji", async function (assert) {
    this.didSelectEmoji = (emoji) => assert.step(emoji);

    await render(
      <template><Content @didSelectEmoji={{this.didSelectEmoji}} /></template>
    );
    await click('img.emoji[data-emoji="grinning"]');

    assert.verifySteps(["grinning"]);
  });

  test("When navigating sections", async function (assert) {
    await render(<template><Content /></template>);

    // Force all sections to render
    await click(`.emoji-picker__section-btn[data-section="objects"]`);

    document.querySelector(".filter-input").focus();
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");

    assert
      .dom(document.activeElement)
      .hasAttribute(
        "data-emoji",
        "grinning",
        "ArrowDown focuses on the first favorite emoji"
      );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");

    assert
      .dom(document.activeElement)
      .hasAttribute("data-emoji", "raised_hands");

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowRight");

    assert
      .dom(document.activeElement)
      .hasAttribute(
        "data-emoji",
        "man_rowing_boat",
        "ArrowRight focuses on the emoji at the right"
      );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowLeft");
    assert
      .dom(document.activeElement)
      .hasAttribute(
        "data-emoji",
        "raised_hands",
        "ArrowLeft focuses on the emoji at the left"
      );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowUp");
    assert.dom(document.activeElement).hasAttribute("data-emoji", "grinning");
  });

  test("When navigating filtered emojis", async function (assert) {
    await render(<template><Content /></template>);

    await fillIn(".filter-input", "_rowing_");

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    assert
      .dom(document.activeElement)
      .hasAttribute(
        "data-emoji",
        "man_rowing_boat",
        "ArrowDown focuses on the first filtered emoji"
      );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowRight");
    assert
      .dom(document.activeElement)
      .hasAttribute(
        "data-emoji",
        "person_rowing_boat",
        "ArrowRight focuses on the emoji at the right"
      );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowLeft");
    assert
      .dom(document.activeElement)
      .hasAttribute(
        "data-emoji",
        "man_rowing_boat",
        "ArrowLeft focuses on the emoji at the left"
      );
  });

  test("When selecting a toned an emoji", async function (assert) {
    this.didSelectEmoji = (emoji) => assert.step(emoji);

    await render(
      <template><Content @didSelectEmoji={{this.didSelectEmoji}} /></template>
    );
    const picker = emojiPicker(".emoji-picker");
    await picker.select("raised_hands");
    await picker.tone(2);
    await picker.select("raised_hands");

    assert.verifySteps(["raised_hands", "raised_hands:t2"]);
  });

  test("CDN url", async function (assert) {
    this.siteSettings.external_emoji_url = "https://emoji.com";

    await render(<template><Content /></template>);

    assert
      .dom('img[data-emoji="grinning"]')
      .hasAttribute(
        "src",
        `https://emoji.com/twitter/grinning.png?v=${v}`,
        "it uses the external emoji url"
      );
  });

  test("When hovering an emoji", async function (assert) {
    await render(<template><Content /></template>);

    assert
      .dom(
        '.emoji-picker__section[data-section="people_&_body"] img.emoji:nth-child(1)'
      )
      .hasAttribute("title", ":raised_hands:", "first emoji has a title");

    await emojiPicker(".emoji-picker").fill("grinning");

    assert
      .dom('img.emoji[data-emoji="grinning_face"]')
      .hasAttribute("title", ":grinning_face:", "filtered emoji have a title");

    await emojiPicker(".emoji-picker").tone(1);
    await render(<template><Content /></template>);

    assert
      .dom('img.emoji[data-emoji="raised_hands"]')
      .hasAttribute(
        "title",
        ":raised_hands:",
        "it has a title without the scale as diversity value is 1"
      );

    await emojiPicker(".emoji-picker").tone(2);
    await render(<template><Content /></template>);

    assert
      .dom('img.emoji[data-emoji="raised_hands"]')
      .hasAttribute(
        "title",
        ":raised_hands:t2:",
        "it has a title with the scale"
      );
  });

  module("skin tone with new select controls", function (flagHooks) {
    flagHooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
    });

    test("shows the current tone's clap, and says which tone it is", async function (assert) {
      await render(<template><Content /></template>);

      assert.dSelect(TONE).hasValue(1);
      assert
        .dom(TONE)
        .hasAttribute("role", "combobox")
        .hasAria("label", i18n("emoji_picker.skin_tone"))
        .hasText(toneName(1));
      assert
        .dom(`${TONE} img.emoji`)
        .hasAttribute("src", clapUrl(1))
        .hasAttribute("alt", "");
      assert.dom(`${TONE} .d-select__caret`).doesNotExist();
    });

    test("lists the six tones by name with their claps, and checks the current one", async function (assert) {
      await render(<template><Content /></template>);
      await dSelect(TONE).open();

      assert.dSelect(TONE).hasOptions([1, 2, 3, 4, 5, 6]);
      assert.deepEqual(
        findAll("[role='option']").map((row) => row.textContent.trim()),
        [1, 2, 3, 4, 5, 6].map(toneName)
      );
      assert.deepEqual(
        findAll("[role='option'] img.emoji").map((img) => [
          img.getAttribute("src"),
          img.getAttribute("alt"),
        ]),
        [1, 2, 3, 4, 5, 6].map((scale) => [clapUrl(scale), ""])
      );
      assert.dSelect(TONE).hasSelectedOption(1);
    });

    test("applies and stores the picked tone", async function (assert) {
      await render(<template><Content /></template>);
      await dSelect(TONE).select(6);

      assert.strictEqual(this.emojiStore.diversity, 6);
      assert.strictEqual(
        this.emojiStore.store.getObject(SKIN_TONE_STORE_KEY),
        6,
        "it remembers the tone"
      );
      assert
        .dom(`img[src="/images/emoji/twitter/raised_hands/6.png?v=${v}"]`)
        .exists("it applies the tone to emojis");
      assert.dSelect(TONE).hasValue(6);
      assert.dom(TONE).hasText(toneName(6));
      assert.dom(`${TONE} img.emoji`).hasAttribute("src", clapUrl(6));

      await dSelect(TONE).select(1);

      assert.strictEqual(this.emojiStore.diversity, 1);
      assert
        .dom(`img[src="/images/emoji/twitter/raised_hands.png?v=${v}"]`)
        .exists("it removes the tone from emojis");
      assert.dSelect(TONE).hasValue(1);
    });

    test("starts at the stored tone", async function (assert) {
      this.emojiStore.diversity = 4;
      await render(<template><Content /></template>);

      assert.dSelect(TONE).hasValue(4);
      assert.dom(TONE).hasText(toneName(4));
      assert.dom(`${TONE} img.emoji`).hasAttribute("src", clapUrl(4));
    });

    test("keeps the tone when Backspace is pressed on it, and doesn't say it was cleared", async function (assert) {
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
      await render(<template><Content /></template>);
      await dSelect(TONE).select(3);
      await focus(TONE);
      await triggerKeyEvent(TONE, "keydown", "Backspace");

      assert.dSelect(TONE).hasValue(3);
      assert.strictEqual(this.emojiStore.diversity, 3);
      assert.false(
        announce.calledWith(i18n("d_select.selection_cleared")),
        "nothing was cleared"
      );
    });

    test("Escape closes only the tone list, and returns to its trigger", async function (assert) {
      await render(<template><EmojiPicker /></template>);
      await click(".emoji-picker-trigger");
      await dSelect(TONE).open();
      await triggerKeyEvent(TONE, "keydown", "Escape");

      assert.dom("[role='listbox']").doesNotExist("the tone list is closed");
      assert.dom(".emoji-picker").exists("the emoji picker stays open");
      assert.dom(TONE).isFocused();
    });

    test("the emoji picker helper picks a tone", async function (assert) {
      await render(<template><Content /></template>);
      await emojiPicker(".emoji-picker").tone(2);

      assert.strictEqual(this.emojiStore.diversity, 2);
    });
  });
});
