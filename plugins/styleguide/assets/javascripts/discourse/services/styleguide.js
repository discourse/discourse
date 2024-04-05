import Service from "@ember/service";
import loadFaker from "discourse/lib/load-faker";

export default class StyleguideService extends Service {
  faker;

  async ensureFakerLoaded() {
    this.faker ||= (await loadFaker()).faker;
  }
}
