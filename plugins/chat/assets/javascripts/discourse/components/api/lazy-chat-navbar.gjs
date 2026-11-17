import Component from "@glimmer/component";
import DAsyncContent from "discourse/ui-kit/d-async-content";

let loaded;

export default class LazyChatNavbar extends Component {
  get module() {
    return (loaded ??= import("../chat/navbar/index.gjs"));
  }

  <template>
    <DAsyncContent @asyncData={{this.module}}>
      <:loading>
        <div class="c-navbar-container"><nav class="c-navbar"></nav></div>
      </:loading>
      <:content as |module|>
        <module.default @onClick={{@onClick}} as |navbar|>
          {{yield navbar}}
        </module.default>
      </:content>
    </DAsyncContent>
  </template>
}
