import EmberObject, { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class VersionCheck extends EmberObject {
  static find() {
    return ajax("/admin/version_check").then((json) =>
      VersionCheck.create(json)
    );
  }

  @computed("updated_at")
  get noCheckPerformed() {
    return this.updated_at === null;
  }

  @computed("missing_versions_count")
  get upToDate() {
    return (
      this.missing_versions_count === 0 || this.missing_versions_count === null
    );
  }

  @computed("missing_versions_count")
  get behindByOneVersion() {
    return this.missing_versions_count === 1;
  }

  @computed("installed_sha")
  get gitLink() {
    if (this.installed_sha) {
      return `https://github.com/discourse/discourse/commits/${this.installed_sha}`;
    }
  }

  @computed("installed_sha")
  get shortSha() {
    if (this.installed_sha) {
      return this.installed_sha.slice(0, 10);
    }
  }
}
