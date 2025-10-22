import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";

export default class VersionCheck extends EmberObject {
  static find() {
    return ajax("/admin/version_check").then((json) =>
      VersionCheck.create(json)
    );
  }

  @discourseComputed("updated_at")
  noCheckPerformed(updatedAt) {
    return updatedAt === null;
  }

  @discourseComputed("missing_versions_count")
  upToDate(missingVersionsCount) {
    return missingVersionsCount === 0 || missingVersionsCount === null;
  }

  @discourseComputed("missing_versions_count")
  behindByOneVersion(missingVersionsCount) {
    return missingVersionsCount === 1;
  }

  @discourseComputed("installed_sha")
  gitLink(installedSHA) {
    if (installedSHA) {
      return `https://github.com/discourse/discourse/commits/${installedSHA}`;
    }
  }

  @discourseComputed("installed_sha")
  shortSha(installedSHA) {
    if (installedSHA) {
      return installedSHA.slice(0, 10);
    }
  }
}
