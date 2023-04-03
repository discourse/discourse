import PreloadStore from "discourse/lib/preload-store";
import { TrackedObject } from "@ember-compat/tracked-built-ins";

export default class SiteSettingsService {
  static isServiceFactory = true;

  static create() {
    return new TrackedObject(PreloadStore.get("siteSettings"));
  }
}
