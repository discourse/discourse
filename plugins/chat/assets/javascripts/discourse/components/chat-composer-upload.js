import Component from "@glimmer/component";
import { isImage } from "discourse/lib/uploads";

export default class ChatComposerUpload extends Component {
  get isImage() {
    return isImage(
      this.args.upload.original_filename || this.args.upload.fileName
    );
  }

  get fileName() {
    return this.isDone
      ? this.args.upload.original_filename
      : this.args.upload.fileName;
  }
}
