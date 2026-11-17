import Component from "@glimmer/component";
import DAsyncContent from "discourse/ui-kit/d-async-content";

let loaded;

export default class LazyCategoryChat extends Component {
  get module() {
    return (loaded ??= import("./chat.gjs"));
  }

  <template>
    <DAsyncContent @asyncData={{this.module}}>
      <:content as |module|>
        <module.default @category={{@category}} />
      </:content>
    </DAsyncContent>
  </template>
}
