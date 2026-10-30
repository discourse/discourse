import { ajax } from "discourse/lib/ajax";

/** `/admin/version_check` record; the dashboard's copy can omit the latest-version fields. */
export interface VersionCheckPayload {
  installed_version: string;
  installed_sha: string | null;
  installed_describe: string;
  git_branch?: string;
  latest_version?: string | null;
  latest_pretty_version?: string | null;
  latest_sha?: string | null;
  missing_versions_count?: number | null;
  updated_at: string | null;
  version_check_pending?: boolean;
  stale_data?: boolean;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface VersionCheck extends VersionCheckPayload {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class VersionCheck {
  static async find(): Promise<VersionCheck> {
    return new VersionCheck(
      await ajax<VersionCheckPayload>("/admin/version_check")
    );
  }

  constructor(json: VersionCheckPayload = {} as VersionCheckPayload) {
    Object.assign(this, json);
  }

  get noCheckPerformed(): boolean {
    return this.updated_at === null;
  }

  get upToDate(): boolean {
    return (
      this.missing_versions_count === 0 || this.missing_versions_count === null
    );
  }

  get behindByOneVersion(): boolean {
    return this.missing_versions_count === 1;
  }

  get gitLink(): string | undefined {
    return commitLink(this.installed_sha);
  }

  get shortSha(): string | undefined {
    return truncateSha(this.installed_sha);
  }

  get latestGitLink(): string | undefined {
    return commitLink(this.latest_sha);
  }

  get latestShortSha(): string | undefined {
    return truncateSha(this.latest_sha);
  }

  get changelogLink(): string | undefined {
    if (this.installed_sha && this.latest_sha) {
      const start = this.installed_sha.slice(0, 8);
      const end = this.latest_sha.slice(0, 8);
      return `https://releases.discourse.org/changelog/custom?start=${start}&end=${end}`;
    }
  }

  get installedCommitsAhead(): number | undefined {
    return commitsAhead(this.installed_describe);
  }

  get latestCommitsAhead(): number | undefined {
    return commitsAhead(this.latest_pretty_version);
  }

  get newerCommitsAvailable(): boolean {
    return this.newChangesCount > 0;
  }

  get newChangesCount(): number {
    if (this.latestCommitsAhead === undefined) {
      return 0;
    }
    return this.latestCommitsAhead - (this.installedCommitsAhead ?? 0);
  }
}

function commitLink(sha: string | null | undefined): string | undefined {
  if (sha) {
    return `https://github.com/discourse/discourse/commits/${sha}`;
  }
}

function truncateSha(sha: string | null | undefined): string | undefined {
  return sha?.slice(0, 10);
}

function commitsAhead(
  prettyVersion: string | null | undefined
): number | undefined {
  const extra = prettyVersion?.split(" +")[1];
  return extra ? parseInt(extra, 10) : undefined;
}
