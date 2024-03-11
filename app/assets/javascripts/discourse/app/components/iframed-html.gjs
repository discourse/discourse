import Component from "@glimmer/component";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import concatClass from "discourse/helpers/concat-class";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { bind } from "discourse-common/utils/decorators";

export default class IframedHtml extends Component {
  @bind
  writeHtml(element) {
    const iframeDoc = element.contentWindow.document;
    iframeDoc.open("text/html", "replace");
    iframeDoc.write(this.args.html);
    iframeDoc.close();
  }

  <template>
    {{! template-lint-disable require-iframe-title }}
    <iframe
      {{didInsert this.writeHtml}}
      {{didUpdate this.witeHtml @html}}
      sandbox="allow-same-origin"
      class={{concatClass (if @html "iframed-html") @className}}
      ...attributes
    ></iframe>
  </template>
}
