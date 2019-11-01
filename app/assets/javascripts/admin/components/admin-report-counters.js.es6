import Component from "@ember/component";
export default Component.extend({
  classNames: ["admin-report-counters"],

  attributeBindings: ["model.description:title"]
});
