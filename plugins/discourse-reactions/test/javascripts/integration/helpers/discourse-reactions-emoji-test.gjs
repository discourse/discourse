import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { replaceIcon, REPLACEMENTS } from "discourse/lib/icon-library";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import discourseReactionsEmoji from "discourse/plugins/discourse-reactions/discourse/helpers/discourse-reactions-emoji";

module("Integration | Helper | discourse-reactions-emoji", function (hooks) {
  setupRenderingTest(hooks);

  let originalLikeIcon;

  hooks.beforeEach(function () {
    this.siteSettings.enable_emoji = false;
    this.siteSettings.discourse_reactions_reaction_for_like = "heart";
    this.siteSettings.discourse_reactions_like_icon = "heart";
    originalLikeIcon = REPLACEMENTS["d-liked"];
  });

  hooks.afterEach(function () {
    replaceIcon("d-liked", originalLikeIcon);
  });

  test("uses the configured reaction and icon for likes", async function (assert) {
    this.siteSettings.discourse_reactions_reaction_for_like = "+1";
    this.siteSettings.discourse_reactions_like_icon = "star";

    await render(
      <template>
        {{discourseReactionsEmoji "+1" class="users-popup__reaction"}}
      </template>
    );

    assert
      .dom("svg.users-popup__reaction use")
      .hasAttribute(
        "href",
        "#star",
        "the custom like icon retains the supplied class"
      );
    assert
      .dom("svg")
      .hasAria("label", "+1", "the reaction has an accessible label");
  });

  test("respects theme replacements for the like icon", async function (assert) {
    replaceIcon("d-liked", "thumbs-up");

    await render(<template>{{discourseReactionsEmoji "heart"}}</template>);

    assert
      .dom("svg use")
      .hasAttribute("href", "#thumbs-up", "the heart uses the d-liked alias");
  });

  test("renders likes as emoji when emojis are enabled", async function (assert) {
    this.siteSettings.enable_emoji = true;

    await render(
      <template>
        {{discourseReactionsEmoji "heart" class="users-popup__reaction"}}
      </template>
    );

    assert
      .dom("img.emoji.users-popup__reaction")
      .hasAttribute("alt", "heart", "the like remains an emoji image");
    assert
      .dom("img.emoji")
      .hasAttribute("title", "heart", "the emoji keeps its tooltip");
  });

  test("keeps other reactions as text when emojis are disabled", async function (assert) {
    this.siteSettings.discourse_reactions_reaction_for_like = "+1";

    await render(
      <template>
        <span>{{discourseReactionsEmoji "heart"}}</span>
      </template>
    );

    assert
      .dom("span")
      .hasText(
        ":heart:",
        "the fallback only applies to the configured like reaction"
      );
  });
});
