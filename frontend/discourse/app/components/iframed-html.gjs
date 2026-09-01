import Component from "@glimmer/component";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { bind } from "discourse/lib/decorators";

export default class IframedHtml extends Component {
  @bind
  writeHtml(element) {
    const iframeDoc = element.contentWindow.document;
    iframeDoc.open("text/html", "replace");
    iframeDoc.write(this.args.html);
    iframeDoc.close();
  }

  <template>
    {{! eslint-disable ember/template-require-iframe-title }}
    <iframe
      class={{if @html "iframed-html"}}
      sandbox="allow-same-origin"
      ...attributes
      {{didInsert this.writeHtml}}
      {{didUpdate this.witeHtml @html}}
    ></iframe>
  </template>
}
