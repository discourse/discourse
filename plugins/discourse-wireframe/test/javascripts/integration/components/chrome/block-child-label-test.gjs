import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import BlockChrome from "discourse/plugins/discourse-wireframe/discourse/components/editor/chrome/block-chrome";
import { queryOf } from "../../../helpers/wireframe-peers";

const WrappedTabPanel = <template>
  <div>Tab panel</div>
</template>;

module(
  "Integration | discourse-wireframe | block-chrome child label",
  function (hooks) {
    setupRenderingTest(hooks);

    test("uses a rich-inline tab label as the toolbar title", async function (assert) {
      const wireframe = this.owner.lookup("service:wireframe-workspace");
      const query = queryOf(wireframe);
      const child = { block: "section", __stableKey: "child" };

      this.owner.lookup("service:wireframe-edit-mode").activate();
      query.findEntryParent = () => ({ block: "tabs", children: [child] });
      query.blockNameOf = () => "tabs";
      query.findEntryAndOutletSync = () => ({
        entry: {
          ...child,
          containerArgs: {
            tab: {
              label: {
                content: [
                  { type: "text", text: "Pricing" },
                  { type: "text", text: " plans" },
                ],
              },
            },
          },
        },
        outletName: "test-outlet",
      });

      await render(
        <template>
          <BlockChrome
            @blockName="section"
            @blockKey="section:child"
            @outletName="test-outlet"
            @WrappedComponent={{WrappedTabPanel}}
          />
        </template>
      );

      assert
        .dom(".wireframe-block-toolbar__handle > span")
        .hasAttribute(
          "title",
          "Pricing plans",
          "the rich-inline child label remains available as the title"
        );
    });
  }
);
