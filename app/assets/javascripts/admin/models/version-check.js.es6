import { ajax } from "discourse/lib/ajax";
import computed from "ember-addons/ember-computed-decorators";

const VersionCheck = Discourse.Model.extend({
  @computed("updated_at")
  noCheckPerformed(updatedAt) {
    return updatedAt === null;
  },

  @computed("missing_versions_count")
  upToDate(missingVersionsCount) {
    return missingVersionsCount === 0 || missingVersionsCount === null;
  },

  @computed("missing_versions_count")
  behindByOneVersion(missingVersionsCount) {
    return missingVersionsCount === 1;
  },

  @computed("installed_sha")
  gitLink(installedSHA) {
    if (installedSHA) {
      return `https://github.com/discourse/discourse/commits/${installedSHA}`;
    }
  },

  @computed("installed_sha")
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
