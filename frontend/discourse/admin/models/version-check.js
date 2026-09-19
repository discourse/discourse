import { ajax } from "discourse/lib/ajax";

export default class VersionCheck {
  static async find() {
    return new VersionCheck(await ajax("/admin/version_check"));
  }

  constructor(json = {}) {
    Object.assign(this, json);
  }

  get noCheckPerformed() {
    return this.updated_at === null;
  }

  get upToDate() {
    return (
      this.missing_versions_count === 0 || this.missing_versions_count === null
    );
  }

  get behindByOneVersion() {
    return this.missing_versions_count === 1;
  }

  get gitLink() {
    return commitLink(this.installed_sha);
  }

  get shortSha() {
    return truncateSha(this.installed_sha);
  }

  get latestGitLink() {
    return commitLink(this.latest_sha);
  }

  get latestShortSha() {
    return truncateSha(this.latest_sha);
  }

  get changelogLink() {
    if (this.installed_sha && this.latest_sha) {
      const start = this.installed_sha.slice(0, 8);
      const end = this.latest_sha.slice(0, 8);
      return `https://releases.discourse.org/changelog/custom?start=${start}&end=${end}`;
    }
  }

  get installedCommitsAhead() {
    return commitsAhead(this.installed_describe);
  }

  get latestCommitsAhead() {
    return commitsAhead(this.latest_pretty_version);
  }

  get newerCommitsAvailable() {
    return this.newChangesCount > 0;
  }

  get newChangesCount() {
    if (this.latestCommitsAhead === undefined) {
      return 0;
    }
    return this.latestCommitsAhead - (this.installedCommitsAhead ?? 0);
  }
}

function commitLink(sha) {
  if (sha) {
    return `https://github.com/discourse/discourse/commits/${sha}`;
  }
}

function truncateSha(sha) {
  return sha?.slice(0, 10);
}

function commitsAhead(prettyVersion) {
  const extra = prettyVersion?.split(" +")[1];
  return extra ? parseInt(extra, 10) : undefined;
}
