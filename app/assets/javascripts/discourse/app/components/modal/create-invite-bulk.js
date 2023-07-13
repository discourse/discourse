import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import CreateInviteUploader from "discourse/components/create-invite-uploader";
import { TrackedObject } from "@ember-compat/tracked-built-ins";

export default class CreateInviteBulk extends Component {
  @tracked uploader = new TrackedObject();

  @action
  setUploader(value) {
    this.uploader = value;
    console.log(this.uploader);
  }

  @action
  uploading() {
    this.uploader.set("data", data);
  }
}
