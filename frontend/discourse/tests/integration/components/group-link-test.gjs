import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import GroupLink from "discourse/components/group-link";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | GroupLink", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the group card contract with a supplied href", async function (assert) {
    await render(
      <template>
        <GroupLink @href="/custom/team" @name="team">Team</GroupLink>
      </template>
    );

    assert
      .dom("a.user-group.trigger-group-card")
      .hasAttribute("href", "/custom/team", "preserves the supplied href")
      .hasAttribute(
        "data-group-card",
        "team",
        "identifies the group for the card"
      )
      .hasText("Team", "renders the link contents");
  });

  test("uses the group URL and name", async function (assert) {
    this.group = { name: "developers", url: "/g/developers" };

    await render(
      <template>
        <GroupLink @group={{this.group}}>Developers</GroupLink>
      </template>
    );

    assert
      .dom("a.user-group.trigger-group-card")
      .hasAttribute("href", "/g/developers", "uses the group URL")
      .hasAttribute(
        "data-group-card",
        "developers",
        "uses the group name for the card"
      );
  });
});
