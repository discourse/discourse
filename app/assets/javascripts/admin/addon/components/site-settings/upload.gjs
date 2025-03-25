import Component from "@ember/component";
import { action } from "@ember/object";

export default class Upload extends Component {
  @action
  uploadDone(upload) {
    this.set("value", upload.url);
  }
}
