import SelectedNameComponent from "select-box-kit/components/multi-combo-box/selected-name";

export default SelectedNameComponent.extend({
  didRender() {
    const name = this.get("content.name");
    this.$().css("border-bottom", Handlebars.Utils.escapeExpression(`7px solid #${name}`));
  }
});
