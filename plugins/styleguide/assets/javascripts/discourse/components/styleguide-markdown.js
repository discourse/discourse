/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { cook } from "discourse/lib/text";

export default class StyleguideMarkdown extends Component {
  didInsertElement() {
    super.didInsertElement(...arguments);

    const contents = this.element.innerHTML;
    cook(contents).then(
      (cooked) => (this.element.innerHTML = cooked.toString())
    );
  }
}
