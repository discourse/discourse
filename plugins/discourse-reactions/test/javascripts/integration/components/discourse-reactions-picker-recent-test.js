import { click, render } from "@ember/test-helpers";
import { test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";

test("recent any reactions are displayed when any emoji is enabled", async function (assert) {
  this.set("post", {
    id: 1,
    current_user_reaction: null,
    current_user_used_main_reaction: false,
    likeAction: { canToggle: true },
  });

  this.set("toggle", () => {});
  this.set("scheduleCollapse", () => {});
  this.set("cancelCollapse", () => {});
  this.set("reactionsPickerExpanded", true);

  this.owner.lookup("service:site-settings").setProperties({
    discourse_reactions_enabled_reactions: "heart|thumbsup",
    discourse_reactions_reaction_for_like: "heart",
    discourse_reactions_experimental_allow_any_emoji: true,
    discourse_reactions_recent_any_reactions_count: 3,
  });

  // Add some recent reactions to the store
  const recentStore = this.owner.lookup("service:recent-any-reactions-store");
  recentStore.trackAnyReaction("grinning");
  recentStore.trackAnyReaction("cat");
  recentStore.trackAnyReaction("dog");

  await render(hbs`
    <DiscourseReactionsPicker
      @post={{this.post}}
      @toggle={{this.toggle}}
      @scheduleCollapse={{this.scheduleCollapse}}
      @cancelCollapse={{this.cancelCollapse}}
      @reactionsPickerExpanded={{this.reactionsPickerExpanded}}
    />
  `);

  // Check that recent reactions are displayed
  assert.dom(".recent-any-reaction").exists({ count: 3 });
  assert.dom(".recent-any-reaction[data-reaction='grinning']").exists();
  assert.dom(".recent-any-reaction[data-reaction='cat']").exists();
  assert.dom(".recent-any-reaction[data-reaction='dog']").exists();
});

test("recent any reactions exclude duplicates from main reaction list", async function (assert) {
  this.set("post", {
    id: 1,
    current_user_reaction: null,
    current_user_used_main_reaction: false,
    likeAction: { canToggle: true },
  });

  this.set("toggle", () => {});
  this.set("scheduleCollapse", () => {});
  this.set("cancelCollapse", () => {});
  this.set("reactionsPickerExpanded", true);

  this.owner.lookup("service:site-settings").setProperties({
    discourse_reactions_enabled_reactions: "heart|thumbsup|grinning",
    discourse_reactions_reaction_for_like: "heart",
    discourse_reactions_experimental_allow_any_emoji: true,
    discourse_reactions_recent_any_reactions_count: 3,
  });

  // Add recent reactions including one that's already in the main list
  const recentStore = this.owner.lookup("service:recent-any-reactions-store");
  recentStore.trackAnyReaction("grinning"); // This is already in enabled_reactions
  recentStore.trackAnyReaction("cat");
  recentStore.trackAnyReaction("dog");

  await render(hbs`
    <DiscourseReactionsPicker
      @post={{this.post}}
      @toggle={{this.toggle}}
      @scheduleCollapse={{this.scheduleCollapse}}
      @cancelCollapse={{this.cancelCollapse}}
      @reactionsPickerExpanded={{this.reactionsPickerExpanded}}
    />
  `);

  // Check that grinning is not shown as a recent reaction (it's in the main list)
  assert.dom(".recent-any-reaction[data-reaction='grinning']").doesNotExist();
  // But cat and dog should be shown
  assert.dom(".recent-any-reaction[data-reaction='cat']").exists();
  assert.dom(".recent-any-reaction[data-reaction='dog']").exists();
});