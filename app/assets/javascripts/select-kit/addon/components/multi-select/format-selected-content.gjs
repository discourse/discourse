import Component from "@ember/component";
import { computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import { makeArray } from "discourse/lib/helpers";
import selectKitPropUtils from "select-kit/lib/select-kit-prop-utils";

@tagName("")
@selectKitPropUtils
export default class FormatSelectedContent extends Component {
  content = null;
  selectKit = null;

  @computed("content")
  get formattedContent() {
    if (this.content) {
      return makeArray(this.content)
        .map((c) => this.getName(c))
        .join(", ");
    } else {
      return this.getName(this.selectKit.noneItem);
    }
  }

  <template>
    <span class="formatted-selection">
      {{this.formattedContent}}
    </span>
  </template>
}
