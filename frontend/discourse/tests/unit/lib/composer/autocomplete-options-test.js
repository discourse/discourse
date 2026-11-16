import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { emojiAutocompleteOptions } from "discourse/lib/composer/autocomplete-options";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";

module("Unit | Lib | composer autocomplete options", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/emojis/search-aliases.json", () => response({}));

    this.site = { denied_emojis: ["poop"] };
    this.siteSettings = { emoji_autocomplete_min_chars: 0 };
    this.emojiStore = {
      diversity: 1,
      favoritesForContext: () => ["poop", "heart"],
      trackEmojiForContext: sinon.stub(),
    };
    this.build = (opts = {}) =>
      emojiAutocompleteOptions({
        site: this.site,
        siteSettings: this.siteSettings,
        emojiStore: this.emojiStore,
        context: "chat",
        openPicker: sinon.stub(),
        ...opts,
      });
  });

  test("matches a partial term after allowed characters", function (assert) {
    const { onKeyUp } = this.build();

    assert.deepEqual(onKeyUp("hello :gri", 10), [":gri"]);
    assert.deepEqual(onKeyUp("(:gri", 5), [":gri"]);
    assert.strictEqual(onKeyUp("hello:gri", 9), undefined);
  });

  test("suggests favorites without denied emojis for an empty term", async function (assert) {
    const results = await this.build().dataSource("");

    assert.deepEqual(
      results.map((result) => result.code ?? result.label),
      ["heart", i18n("composer.more_emoji")]
    );
  });

  test("honours the minimum length and ignores typed emoticons", async function (assert) {
    const options = this.build({ minLength: 2, ignoreEmoticons: true });

    assert.deepEqual(await options.dataSource("g"), [], "below the minimum");
    assert.deepEqual(await options.dataSource("-p"), [], "an emoticon");
    assert.notDeepEqual(await options.dataSource("smile"), []);
  });

  test("tracks picked emojis and opens the picker for more", async function (assert) {
    const openPicker = sinon.stub();
    const { transformComplete } = this.build({ openPicker });

    assert.strictEqual(await transformComplete({ code: "heart" }), "heart:");
    assert.true(
      this.emojiStore.trackEmojiForContext.calledWith("heart", "chat")
    );

    assert.strictEqual(await transformComplete({ term: "gri" }), "");
    assert.true(openPicker.calledWith("gri"));
  });
});
