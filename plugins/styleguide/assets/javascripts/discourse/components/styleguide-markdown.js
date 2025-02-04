import Component from "@ember/component";
import $ from "jquery";
import { cook } from "discourse/lib/text";

export default class StyleguideMarkdown extends Component {
  didInsertElement() {
    super.didInsertElement(...arguments);

    const contents = $(this.element).html();
    cook(contents).then((cooked) => $(this.element).html(cooked.toString()));
  }
}
