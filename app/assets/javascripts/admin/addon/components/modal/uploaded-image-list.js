import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class UploadedImageList extends Component {
  @tracked
  images = this.args.model.value?.length
    ? this.args.model.value.split("|")
    : [];

  @action
  remove(url, event) {
    event.preventDefault();
    this.images.removeObject(url);
  }

  @action
  uploadDone({ url }) {
    this.images.addObject(url);
  }

  @action
  close() {
    this.args.model.changeValue(this.images.join("|"));
    this.args.closeModal();
  }
}
