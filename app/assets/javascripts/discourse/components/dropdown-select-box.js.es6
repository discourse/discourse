import computed from "ember-addons/ember-computed-decorators";
import SelectBoxComponent from "discourse/components/select-box";

export default SelectBoxComponent.extend({
  classNames: ["dropdown-select-box"],
  wrapper: false,
  verticalOffset: 3,
  collectionHeight: "auto",
  fullWidthOnMobile: true,
  selectBoxHeaderComponent: "dropdown-select-box/dropdown-header",

  @computed
  templateForRow: function() {
    return (rowComponent) => {
      let template = "";
      const content = rowComponent.get("content");

      const icon = rowComponent.icon();
      if (icon) {
        template += `<div class="icons">${icon}</div>`;
      }

      template += `
        <div class="texts">
          <span class="title">${Handlebars.escapeExpression(Ember.get(content, this.get("textKey")))}</span>
          <span class="desc">${Handlebars.escapeExpression(content.description)}</span>
        </div>
      `;

      return template;
    };
  }
});
