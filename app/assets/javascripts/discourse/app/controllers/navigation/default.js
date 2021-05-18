import Controller, { inject as controller } from "@ember/controller";
import FilterModeMixin from "discourse/mixins/filter-mode";

export default Controller.extend(FilterModeMixin, {
  discovery: controller(),
});
