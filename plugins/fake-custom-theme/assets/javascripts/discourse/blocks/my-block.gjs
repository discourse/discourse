import Component from "@glimmer/component";
import { block } from "discourse/blocks";

@block("my-block")
export default class MyBlock extends Component {
  foo = "bar";

  <template>Hello world</template>
}
