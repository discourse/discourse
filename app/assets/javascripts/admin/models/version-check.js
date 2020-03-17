import discourseComputed from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import EmberObject from "@ember/object";

const VersionCheck = EmberObject.extend({
  @discourseComputed("updated_at")
  noCheckPerformed(updatedAt) {
    return updatedAt === null;
  },

  @discourseComputed("missing_versions_count")
  upToDate(missingVersionsCount) {
    return missingVersionsCount === 0 || missingVersionsCount === null;
  },

  @discourseComputed("missing_versions_count")
  behindByOneVersion(missingVersionsCount) {
    return missingVersionsCount === 1;
  },

  @discourseComputed("installed_sha")
  gitLink(installedSHA) {
    if (installedSHA) {
      return `https://github.com/discourse/discourse/commits/${installedSHA}`;
    }
  },

  @discourseComputed("installed_sha")
  shortSha(installedSHA) {
    if (installedSHA) {
      return installedSHA.substr(0, 10);
    }
  }
});

VersionCheck.reopenClass({
  find() {
    return ajax("/admin/version_check").then(json => VersionCheck.create(json));
  }
});

export default VersionCheck;
