import SelectedNameComponent from "select-kit/components/multi-select/selected-name";
import computed from "ember-addons/ember-computed-decorators";

export default SelectedNameComponent.extend({
  classNames: "selected-color",

  @computed("name")
  footerContent(name) {
    return `<span class="color-preview" style="background:#${name}"></span>`.htmlSafe();
  }
});
