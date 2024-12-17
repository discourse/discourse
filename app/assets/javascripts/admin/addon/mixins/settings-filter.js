import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Mixin from "@ember/object/mixin";

export default Mixin.create({
  filter: tracked({ value: "" }),
  queryParams: ["filter"],

  filterChangedCallback: action(function (filter) {
    this.filter = filter;
  }),
});
