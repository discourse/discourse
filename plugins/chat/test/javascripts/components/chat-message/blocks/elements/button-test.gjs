import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Button from "discourse/plugins/chat/discourse/components/chat-message/blocks/elements/button";

module(
  "Component | ChatMessage | Blocks | Elements | Button",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders each supported button style", async function (assert) {
      const styles = [
        "default",
        "primary",
        "danger",
        "success",
        "flat",
        "transparent",
      ];
      this.definitions = styles.map((style) => ({
        action_id: style,
        style,
        text: { text: style },
      }));

      await render(
        <template>
          {{#each this.definitions as |definition|}}
            <Button @definition={{definition}} />
          {{/each}}
        </template>
      );

      for (const style of styles) {
        assert
          .dom(`#${style}`)
          .hasClass(`btn-${style}`, `${style} uses the matching button class`);
      }
    });

    test("renders an icon with the button label", async function (assert) {
      this.definition = {
        action_id: "approve",
        icon: "check",
        text: { text: "Approve" },
      };

      await render(
        <template><Button @definition={{this.definition}} /></template>
      );

      assert.dom("#approve").hasText("Approve", "the button renders its label");
      assert
        .dom("#approve .d-icon-check")
        .exists("the button renders its configured icon");
    });

    test("preserves the legacy button without a style or icon", async function (assert) {
      this.definition = {
        action_id: "approve",
        text: { text: "Approve" },
      };

      await render(
        <template><Button @definition={{this.definition}} /></template>
      );

      assert
        .dom("#approve")
        .hasClass("btn", "the base button class is present");
      assert
        .dom("#approve")
        .doesNotHaveClass(/btn-.+/, "no button style class is added");
      assert
        .dom("#approve .d-icon")
        .doesNotExist("no icon is rendered by default");
    });
  }
);
