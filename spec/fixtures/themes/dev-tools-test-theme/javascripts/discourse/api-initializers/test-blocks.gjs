import Component from "@glimmer/component";
import { block } from "discourse/components/block-outlet";
import { apiInitializer } from "discourse/lib/api";

@block("dev-tools-test-block", {
  args: { title: { type: "string" } },
})
class TestBlock extends Component {
  <template>
    <div class="dev-tools-test-block">{{@title}}</div>
  </template>
}

@block("dev-tools-conditional-block")
class ConditionalBlock extends Component {
  <template>
    <div class="dev-tools-conditional-block">Admin Only</div>
  </template>
}

export default apiInitializer((api) => {
  api.registerBlock(TestBlock);
  api.registerBlock(ConditionalBlock);

  api.renderBlocks("hero-blocks", [
    { block: TestBlock, args: { title: "Test Title" } },
    { block: ConditionalBlock, conditions: [{ type: "user", loggedIn: true, admin: true }] },
  ]);
});
