import SelectedNameComponent from "select-kit/components/multi-select/selected-name";

export default SelectedNameComponent.extend({
  classNames: "selected-color",
  layoutName: "select-kit/templates/components/multi-select/selected-color",

  didRender() {
    const name = this.get("content.name");
    this.$(".color-preview").css("background", `#${name}`.htmlSafe());
  }
});
