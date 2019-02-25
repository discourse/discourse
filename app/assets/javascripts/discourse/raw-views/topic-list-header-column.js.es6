export default Ember.Object.extend({
  localizedName: function() {
    if (this.forceName) {
      return this.forceName;
    }

    return this.name ? I18n.t(this.name) : "";
  }.property(),

  sortIcon: function() {
    return "chevron-" + (this.parent.ascending ? "up" : "down");
  }.property(),

  isSorting: function() {
    return this.sortable && this.parent.order === this.order;
  }.property(),

  className: function() {
    var name = [];
    if (this.order) {
      name.push(this.order);
    }
    if (this.sortable) {
      name.push("sortable");

      if (this.get("isSorting")) {
        name.push("sorting");
      }
    }

    if (this.number) {
      name.push("num");
    }

    return name.join(" ");
  }.property()
});
