import PreloadStore from "discourse/lib/preload-store";

export default class SiteSettingsService {
  static isServiceFactory = true;

  static create() {
    return PreloadStore.get("siteSettings");
  }
}
