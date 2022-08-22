import Component from "@ember/component";
import layout from "../templates/components/a11y-dialog-wrapper";
import { inject as service } from "@ember/service";

export default Component.extend({
  dialog: service(),
  layout,
  tagName: "",
});
