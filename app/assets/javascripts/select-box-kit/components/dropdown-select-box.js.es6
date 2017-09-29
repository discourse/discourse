import computed from "ember-addons/ember-computed-decorators";
import SelectBoxKitComponent from "select-box-kit/components/select-box-kit";

export default SelectBoxKitComponent.extend({
  classNames: ["dropdown-select-box"],
  verticalOffset: 3,
  collectionHeight: "auto",
  fullWidthOnMobile: true,
  headerComponent: "dropdown-select-box/dropdown-select-box-header",

  @computed
  templateForRow() {
    return (rowComponent) => {
      let template = "";
      const content = rowComponent.get("content");

      const icon = rowComponent.icon();
      if (icon) {
        template += `<div class="icons">${icon}</div>`;
      }

      const title = Ember.get(content, this.get("nameProperty"));
      const desc = Ember.get(content, "description");

      template += `
        <div class="texts">
          <span class="title">${Handlebars.escapeExpression(title)}</span>
          <span class="desc">${Handlebars.escapeExpression(desc)}</span>
        </div>
      `;

      return template;
    };
  },

  actions: {
    onSelectRow(content) {
      this._super();

      this.set("value", content);
    }
  },
});
