import Component from "@glimmer/component";
import { block } from "discourse/blocks";

@block("my-block")
export default class MyBlock extends Component {
  foo = "bar";

  <template>
    <div class="block-my-block__container">
      <div class="block-my-block__layout">
        <h2>My Block</h2>
        <p>This is my custom block content.</p>
        <p>{{@message}}</p>
      </div>
    </div>
  </template>
}
