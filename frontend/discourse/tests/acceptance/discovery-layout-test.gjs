import Component from "@glimmer/component";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { block } from "discourse/blocks";
import { _renderBlocks } from "discourse/blocks/block-outlet";
import {
  registerBlock,
  withTestBlockRegistration,
} from "discourse/tests/helpers/block-testing";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Discovery Layout", function () {
  test("does not render the discovery-layout wrapper when no blocks are registered", async function (assert) {
    await visit("/latest");

    assert.dom("#list-area").exists();
    assert.dom(".discovery-layout").doesNotExist();
    assert.dom(".discovery-layout__sidebar").doesNotExist();
    assert.dom(".discovery-layout__list").doesNotExist();
  });

  test("renders the discovery-layout wrapper with sidebar when blocks are registered", async function (assert) {
    @block("sidebar-test-block")
    class SidebarTestBlock extends Component {
      <template>
        <div class="sidebar-test-content">Sidebar Content</div>
      </template>
    }

    withTestBlockRegistration(() => {
      registerBlock(SidebarTestBlock);
    });

    _renderBlocks("sidebar-discovery", [{ block: SidebarTestBlock }]);

    await visit("/latest");

    assert.dom(".discovery-layout").exists();
    assert.dom(".discovery-layout__list #list-area").exists();
    assert.dom(".discovery-layout__sidebar").exists();
    assert
      .dom(".discovery-layout__sidebar .sidebar-test-content")
      .hasText("Sidebar Content");
  });
});
