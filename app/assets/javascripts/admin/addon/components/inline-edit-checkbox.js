import Component from "@ember/component";
import { action } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";

@classNames("inline-edit")
export default class InlineEditCheckbox extends Component {
  buffer = null;
  bufferModelId = null;

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    if (this.modelId !== this.bufferModelId) {
      // HACK: The condition above ensures this method is called only when its
      // attributes are changed (i.e. only when `checked` changes).
      //
      // Reproduction steps: navigate to theme #1, switch to theme #2 from the
      // left-side panel, then switch back to theme #1 and click on the <input>
      // element wrapped by this component. It will call `didReceiveAttrs` even
      // though none of the attributes have changed (only `buffer` does).
      this.setProperties({
        buffer: this.checked,
        bufferModelId: this.modelId,
      });
    }
  }

  @discourseComputed("checked", "buffer")
  changed(checked, buffer) {
    return !!checked !== !!buffer;
  }

  @action
  apply() {
    this.set("checked", this.buffer);
    this.action();
  }

  @action
  cancel() {
    this.set("buffer", this.checked);
  }
}
