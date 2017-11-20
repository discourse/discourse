import SelectedNameComponent from "select-box-kit/components/multi-combo-box/selected-name";

export default SelectedNameComponent.extend({
  classNames: "selected-color",
  layoutName: "select-box-kit/templates/components/multi-combo-box/selected-color",

  didRender() {
    const name = this.get("content.name");
    console.log("?????", this.$(".color-preview").length, name)
    this.$(".color-preview").css("background", `#${name}`.htmlSafe());
  }
});
