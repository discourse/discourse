import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class UploadedImageList extends Component {
  @tracked
  images = this.args.model.value?.length
    ? this.args.model.value.split("|")
    : [];

  @action
  remove(url, event) {
    event?.preventDefault();
    this.images.removeObject(url);
  }

  @action
  uploadDone({ url }) {
    this.images.addObject(url);
  }

  @action
  close() {
    this.args.model.save(this.images.join("|"));
    this.args.closeModal();
  }
}
