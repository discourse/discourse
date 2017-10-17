import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  layoutName: "select-box-kit/templates/components/select-box-kit/select-box-kit-header",
  classNames: "select-box-kit-header",
  classNameBindings: ["isFocused"],
  attributeBindings: ["text:data-name"],

  @computed("selectBoxIsExpanded", "caretUpIcon", "caretDownIcon")
  caretIcon(selectBoxIsExpanded, caretUpIcon, caretDownIcon) {
    return selectBoxIsExpanded === true ? caretUpIcon : caretDownIcon;
  },

  click() {
    this.sendAction("onToggle");
    console.log("ontoggle")
    event.stopPropagation();
  }
});
