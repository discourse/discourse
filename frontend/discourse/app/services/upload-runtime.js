import { action } from "@ember/object";
import Service from "@ember/service";
import loadUppy, { isUppyLoaded } from "discourse/lib/load-uppy";

export default class UploadRuntime extends Service {
  get loaded() {
    return isUppyLoaded();
  }

  load() {
    return loadUppy();
  }

  @action
  reload() {
    // Failed module fetches remain cached until the document reloads.
    window.location.reload();
  }
}
