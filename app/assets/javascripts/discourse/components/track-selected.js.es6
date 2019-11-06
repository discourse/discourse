import Component from "@ember/component";
export default Component.extend({
  tagName: "span",
  selectionChanged: function() {
    const selected = this.selected;
    const list = this.selectedList;
    const id = this.selectedId;

    if (selected) {
      list.addObject(id);
    } else {
      list.removeObject(id);
    }
  }.observes("selected")
});
