import type EmberObject from "@ember/object";
import { expectTypeOf } from "expect-type";
import AdminDashboard from "discourse/admin/models/admin-dashboard";
import AdminPlugin, {
  type AdminPluginPayload,
} from "discourse/admin/models/admin-plugin";
import Backup from "discourse/admin/models/backup";
import BackupStatus from "discourse/admin/models/backup-status";
import ScreenedEmail from "discourse/admin/models/screened-email";
import ScreenedIpAddress from "discourse/admin/models/screened-ip-address";
import ScreenedUrl from "discourse/admin/models/screened-url";
import UserExport from "discourse/admin/models/user-export";
import VersionCheck from "discourse/admin/models/version-check";
import WatchedWord from "discourse/admin/models/watched-word";
import type LegacyArrayLikeObject from "discourse/lib/legacy-array-like-object";
import type RestModel from "discourse/models/rest";
import type {
  default as StoreService,
  ModelFor,
} from "discourse/services/store";

type ScreeningAction = "block" | "do_nothing" | "allow_admin";
type WordAction =
  | "block"
  | "censor"
  | "require_approval"
  | "flag"
  | "link"
  | "replace"
  | "tag"
  | "silence";
type BackupFile = { filename: string; size: number; last_modified: string };
type OperationResult = {
  success?: string;
  failed?: string;
  message?: string;
};

declare const store: StoreService;

// The plugins index wraps raw `plugin` records in this separate model.
expectTypeOf<ModelFor<"admin-plugin">>().toEqualTypeOf<AdminPlugin>();
expectTypeOf(
  store.createRecord("admin-plugin", {
    id: "discourse-test-plugin",
    name: "discourse-test-plugin",
    admin_route: {
      location: "discourse-test-plugin",
      label: "admin.plugins.title",
      use_new_show_route: false,
      full_location: "admin",
    },
    has_settings: true,
    has_only_enabled_setting: false,
  })
).toEqualTypeOf<AdminPlugin>();

declare const dashboard: AdminDashboard;
expectTypeOf(dashboard).toExtend<EmberObject>();
expectTypeOf(dashboard).not.toExtend<RestModel>();
expectTypeOf(dashboard).not.toExtend<LegacyArrayLikeObject<unknown>>();
expectTypeOf(AdminDashboard.fetch()).resolves.toEqualTypeOf<AdminDashboard>();
AdminDashboard.fetch({
  startDate: new Date("2026-09-28"),
  endDate: new Date("2026-10-28"),
});
AdminDashboard.fetch({ startDate: new Date("2026-09-28") });
expectTypeOf(
  AdminDashboard.fetchProblems()
).resolves.toEqualTypeOf<AdminDashboard>();
// Fetch and problems populate different subsets of the same model.
expectTypeOf(dashboard.loaded).toEqualTypeOf<boolean | undefined>();
// The general tab and the version check in the index payload were removed with the old dashboard.
expectTypeOf(AdminDashboard).not.toHaveProperty("fetchGeneral");
expectTypeOf(dashboard).not.toHaveProperty("version_check");
expectTypeOf(dashboard.sections).toEqualTypeOf<
  { id: string; data?: unknown; error?: boolean }[] | undefined
>();
expectTypeOf(dashboard.configuration).toEqualTypeOf<
  { sections: { id: string; visible: boolean }[] } | undefined
>();
expectTypeOf(dashboard.problems).toEqualTypeOf<
  | {
      id: number;
      priority: "low" | "high";
      message: string;
      identifier: string;
    }[]
  | undefined
>();
AdminDashboard.create({
  sections: [
    { id: "highlights", data: { kpis: [{ value: null }] } },
    { id: "traffic", data: null, error: true },
    { id: "extension", data: { custom: [1, "two"] } },
  ],
  configuration: { sections: [{ id: "highlights", visible: true }] },
  problems: [],
});
AdminDashboard.create({
  problems: [
    { id: 55, priority: "low", message: "Test mode", identifier: "rails_env" },
  ],
});

declare const plugin: AdminPlugin;
expectTypeOf(plugin).not.toExtend<EmberObject>();
expectTypeOf(plugin).not.toExtend<RestModel>();
expectTypeOf(plugin).not.toExtend<LegacyArrayLikeObject<unknown>>();
expectTypeOf(AdminPlugin.create()).toEqualTypeOf<AdminPlugin>();
expectTypeOf(new AdminPlugin()).toEqualTypeOf<AdminPlugin>();
expectTypeOf(
  new AdminPlugin({ id: "discourse-test-plugin" })
).toEqualTypeOf<AdminPlugin>();
AdminPlugin.create({
  id: "discourse-adplugin",
  name: "discourse-adplugin",
  about: "Configure advertisements",
  version: "1.2.5",
  url: "https://github.com/discourse/discourse/tree/main/plugins/discourse-adplugin",
  admin_route: {
    location: "discourse-adplugin",
    label: "admin.adplugin.house_ads.title",
    use_new_show_route: true,
    auto_generated: false,
    full_location: "adminPlugins.show",
  },
  enabled: false,
  enabled_setting: "discourse_adplugin_enabled",
  has_settings: true,
  has_only_enabled_setting: false,
  humanized_name: "Ad Plugin",
  is_official: true,
  is_discourse_owned: true,
  label: null,
  commit_hash: "13d44d7b",
  commit_url: "https://github.com/discourse/discourse/commit/13d44d7b",
  meta_url: null,
  authors: null,
});
expectTypeOf(plugin.id).toEqualTypeOf<string>();
expectTypeOf(plugin.name).toEqualTypeOf<string>();
// Metadata can be absent on client-created records, or null on the wire.
expectTypeOf(plugin.about).toEqualTypeOf<string | null | undefined>();
expectTypeOf(plugin.version).toEqualTypeOf<string | null | undefined>();
expectTypeOf(plugin.authors).toEqualTypeOf<string | null | undefined>();
expectTypeOf(plugin.url).toEqualTypeOf<string | undefined>();
expectTypeOf(plugin.enabledSetting).toEqualTypeOf<string | undefined>();
expectTypeOf(plugin.humanizedName).toEqualTypeOf<string | undefined>();
expectTypeOf(plugin.enabled).toEqualTypeOf<boolean | undefined>();
expectTypeOf(plugin.hasSettings).toEqualTypeOf<boolean | undefined>();
expectTypeOf(plugin.hasOnlyEnabledSetting).toEqualTypeOf<boolean | undefined>();
expectTypeOf(plugin.isOfficial).toEqualTypeOf<boolean | undefined>();
expectTypeOf(plugin.isDiscourseOwned).toEqualTypeOf<boolean | undefined>();
expectTypeOf(plugin.label).toEqualTypeOf<string | null | undefined>();
expectTypeOf(plugin.commitHash).toEqualTypeOf<string | null | undefined>();
expectTypeOf(plugin.commitUrl).toEqualTypeOf<string | null | undefined>();
expectTypeOf(plugin.metaUrl).toEqualTypeOf<string | null | undefined>();
expectTypeOf(plugin.extras).toEqualTypeOf<
  Record<string, unknown> | undefined
>();
AdminPlugin.create({
  id: "discourse-test-plugin",
  name: "discourse-test-plugin",
  extras: {
    leaderboards: [],
    groups: [{ id: 1, name: "staff" }],
    scores_remaining: 1,
  },
});
expectTypeOf(plugin.adminRoute).toEqualTypeOf<
  | {
      location: string;
      label: string;
      use_new_show_route: boolean;
      auto_generated?: boolean;
      full_location: string;
      plugin_id?: string;
    }
  | null
  | undefined
>();
expectTypeOf(plugin.useNewShowRoute).toEqualTypeOf<boolean | undefined>();
expectTypeOf(plugin.snakeCaseName).toEqualTypeOf<string>();
expectTypeOf(plugin.dasherizedName).toEqualTypeOf<string>();
expectTypeOf(plugin.translatedCategoryName).toEqualTypeOf<string | undefined>();
expectTypeOf(plugin.settingCategoryName).toEqualTypeOf<string>();
expectTypeOf(plugin.nameTitleized).toEqualTypeOf<string>();
expectTypeOf(plugin.nameTitleizedLower).toEqualTypeOf<string>();
expectTypeOf(plugin.author).toEqualTypeOf<string>();
expectTypeOf(plugin.linkUrl).toEqualTypeOf<string | undefined>();
plugin.enabled = false;
plugin.hasSettings = false;
plugin.hasOnlyEnabledSetting = true;
plugin.adminRoute = null;

// Captured: the serializer omits a blank `url`; no plugin record carries `extras` here.
const localDates = {
  id: "discourse-local-dates",
  name: "discourse-local-dates",
  about: "Display a date in your local timezone",
  version: "0.1",
  admin_route: {
    location: "discourse-local-dates",
    label: "discourse_local_dates.title",
    use_new_show_route: true,
    auto_generated: true,
    full_location: "adminPlugins.show",
  },
  enabled: true,
  enabled_setting: "discourse_local_dates_enabled",
  has_settings: true,
  has_only_enabled_setting: false,
  humanized_name: "Local dates",
  is_official: true,
  is_discourse_owned: true,
  label: null,
  commit_hash: "13d44d7b11f30806e0c0b55bfd81abff60f32e95",
  commit_url:
    "https://github.com/discourse/discourse/commit/13d44d7b11f30806e0c0b55bfd81abff60f32e95",
  meta_url: null,
  authors: null,
};
expectTypeOf(localDates).toExtend<AdminPluginPayload>();

// Captured: a plugin with only its enabled setting has no admin route.
const checklist = {
  id: "checklist",
  name: "checklist",
  about: "Add checklist support to Discourse",
  version: "1.0",
  url: "https://github.com/discourse/discourse/tree/main/plugins/checklist",
  enabled: true,
  enabled_setting: "checklist_enabled",
  has_settings: true,
  has_only_enabled_setting: true,
  humanized_name: "Checklist",
  is_official: true,
  is_discourse_owned: true,
  label: null,
  commit_hash: "13d44d7b11f30806e0c0b55bfd81abff60f32e95",
  commit_url:
    "https://github.com/discourse/discourse/commit/13d44d7b11f30806e0c0b55bfd81abff60f32e95",
  meta_url: "https://meta.discourse.org/t/36362",
  authors: "Discourse Team",
};
expectTypeOf(checklist).toExtend<AdminPluginPayload>();

// A third-party plugin has no `label`, and one without a setting has no `enabled_setting`.
const thirdParty = {
  id: "my-plugin",
  name: "my-plugin",
  about: null,
  version: null,
  enabled: true,
  has_settings: false,
  has_only_enabled_setting: false,
  humanized_name: "My plugin",
  is_official: false,
  is_discourse_owned: false,
  commit_hash: null,
  commit_url: null,
  meta_url: null,
  authors: null,
};
expectTypeOf(thirdParty).toExtend<AdminPluginPayload>();

declare const backup: Backup;
// These legacy AJAX destroy methods override Ember's synchronous destroy.
expectTypeOf<Omit<Backup, "destroy">>().toExtend<
  Omit<EmberObject, "destroy">
>();
expectTypeOf(backup).not.toExtend<RestModel>();
expectTypeOf(backup).not.toExtend<LegacyArrayLikeObject<unknown>>();
expectTypeOf(Backup.find()).resolves.toEqualTypeOf<BackupFile[]>();
expectTypeOf(Backup.find()).resolves.not.toExtend<Backup[]>();
Backup.create({
  filename: "forum-2026-10-28-010000-v20261027000000.tar.gz",
  size: 12345,
  last_modified: "2026-10-28T01:00:00.000Z",
});
expectTypeOf(backup.filename).toEqualTypeOf<string>();
expectTypeOf(backup.size).toEqualTypeOf<number>();
expectTypeOf(backup.last_modified).toEqualTypeOf<string>();
expectTypeOf(Backup.start()).resolves.toEqualTypeOf<OperationResult>();
expectTypeOf(Backup.start(false)).resolves.toEqualTypeOf<OperationResult>();
Backup.start(true);
Backup.start(undefined);
expectTypeOf(Backup.cancel()).resolves.toEqualTypeOf<OperationResult>();
expectTypeOf(Backup.rollback()).resolves.toEqualTypeOf<OperationResult>();
expectTypeOf(backup.restore()).resolves.toEqualTypeOf<OperationResult>();
expectTypeOf(backup.destroy()).toExtend<Promise<unknown>>();
expectTypeOf(backup.destroy()).resolves.not.toBeAny();
// @ts-expect-error The uploads switch is a boolean, not a serialized form value.
Backup.start("false");

declare const status: BackupStatus;
expectTypeOf(status).toExtend<EmberObject>();
expectTypeOf(status).not.toExtend<RestModel>();
expectTypeOf(status).not.toExtend<LegacyArrayLikeObject<unknown>>();
BackupStatus.create({
  isOperationRunning: false,
  canRollback: false,
  allowRestore: false,
});
expectTypeOf(status.isOperationRunning).toEqualTypeOf<boolean>();
expectTypeOf(status.canRollback).toEqualTypeOf<boolean>();
expectTypeOf(status.allowRestore).toEqualTypeOf<boolean>();
expectTypeOf(status.restoreEnabled).toEqualTypeOf<boolean>();
expectTypeOf(status.restoreDisabled).toEqualTypeOf<boolean>();
status.set("isOperationRunning", true);

declare const email: ScreenedEmail;
expectTypeOf(email).toExtend<EmberObject>();
expectTypeOf(email).not.toExtend<RestModel>();
expectTypeOf(email).not.toExtend<LegacyArrayLikeObject<unknown>>();
expectTypeOf(ScreenedEmail.findAll()).resolves.toEqualTypeOf<ScreenedEmail[]>();
ScreenedEmail.create({
  id: 67,
  email: "spam@example.com",
  action: "block",
  match_count: 0,
  last_match_at: null,
  created_at: "2026-10-28T01:04:05.393Z",
  ip_address: null,
});
expectTypeOf(email.id).toEqualTypeOf<number>();
expectTypeOf(email.email).toEqualTypeOf<string>();
expectTypeOf(email.action).toEqualTypeOf<ScreeningAction>();
expectTypeOf(email.match_count).toEqualTypeOf<number>();
expectTypeOf(email.last_match_at).toEqualTypeOf<string | null>();
expectTypeOf(email.created_at).toEqualTypeOf<string>();
expectTypeOf(email.ip_address).toEqualTypeOf<string | null | undefined>();
expectTypeOf(email.actionName).toEqualTypeOf<string>();
expectTypeOf(email.clearBlock()).resolves.toEqualTypeOf<{ success: string }>();

declare const ip: ScreenedIpAddress;
expectTypeOf<Omit<ScreenedIpAddress, "destroy">>().toExtend<
  Omit<EmberObject, "destroy">
>();
expectTypeOf(ip).not.toExtend<RestModel>();
expectTypeOf(ip).not.toExtend<LegacyArrayLikeObject<unknown>>();
expectTypeOf(ScreenedIpAddress.findAll(null)).resolves.toEqualTypeOf<
  ScreenedIpAddress[]
>();
ScreenedIpAddress.findAll("5.6.7.0/24");
ScreenedIpAddress.create({
  ip_address: "5.6.7.0/24",
  action_name: "allow_admin",
});
ScreenedIpAddress.create({
  id: 65,
  ip_address: "5.6.7.0/24",
  action_name: "allow_admin",
  match_count: 0,
  last_match_at: null,
  created_at: "2026-10-28T01:04:05.424Z",
});
expectTypeOf(ip.id).toEqualTypeOf<number | undefined>();
expectTypeOf(ip.ip_address).toEqualTypeOf<string>();
expectTypeOf(ip.action_name).toEqualTypeOf<ScreeningAction>();
expectTypeOf(ip.match_count).toEqualTypeOf<number>();
expectTypeOf(ip.last_match_at).toEqualTypeOf<string | null>();
expectTypeOf(ip.created_at).toEqualTypeOf<string>();
expectTypeOf(ip.editing).toEqualTypeOf<boolean | undefined>();
expectTypeOf(ip.isBlocked).toEqualTypeOf<boolean>();
expectTypeOf(ip.isRange).toEqualTypeOf<boolean>();
expectTypeOf(ip.actionName).toEqualTypeOf<string>();
ip.set("action_name", "do_nothing");
ip.action_name = "block";
ip.set("editing", true);
declare const savedIp: Awaited<ReturnType<ScreenedIpAddress["save"]>>;
expectTypeOf(savedIp).not.toBeAny();
expectTypeOf(savedIp.screened_ip_address.id).toEqualTypeOf<number>();
expectTypeOf(savedIp.screened_ip_address.ip_address).toEqualTypeOf<string>();
expectTypeOf(
  savedIp.screened_ip_address.action_name
).toEqualTypeOf<ScreeningAction>();
expectTypeOf(savedIp.screened_ip_address.match_count).toEqualTypeOf<number>();
expectTypeOf(savedIp.screened_ip_address.last_match_at).toEqualTypeOf<
  string | null
>();
expectTypeOf(savedIp.screened_ip_address.created_at).toEqualTypeOf<string>();
expectTypeOf(savedIp.screened_ip_address).not.toExtend<EmberObject>();
expectTypeOf(ip.save()).toExtend<Promise<typeof savedIp>>();
ScreenedIpAddress.create(savedIp.screened_ip_address);
expectTypeOf(ip.destroy()).resolves.toEqualTypeOf<{ success: string }>();
// @ts-expect-error The server rejects unknown screening actions.
ip.action_name = "allow_everyone";

declare const url: ScreenedUrl;
expectTypeOf(url).toExtend<EmberObject>();
expectTypeOf(url).not.toExtend<RestModel>();
expectTypeOf(url).not.toExtend<LegacyArrayLikeObject<unknown>>();
expectTypeOf(ScreenedUrl.findAll()).resolves.toEqualTypeOf<ScreenedUrl[]>();
// The index groups by domain; it does not send individual URL records or ids.
ScreenedUrl.create({
  domain: "spam.example.com",
  action: "do_nothing",
  match_count: 0,
  last_match_at: null,
  created_at: "2026-10-28T01:04:05.450Z",
});
expectTypeOf(url.domain).toEqualTypeOf<string>();
expectTypeOf(url.action).toEqualTypeOf<"do_nothing">();
expectTypeOf(url.match_count).toEqualTypeOf<number>();
expectTypeOf(url.last_match_at).toEqualTypeOf<string | null>();
expectTypeOf(url.created_at).toEqualTypeOf<string>();
expectTypeOf(url.actionName).toEqualTypeOf<string>();

declare const userExport: UserExport;
expectTypeOf(userExport).toExtend<RestModel>();
expectTypeOf(userExport).not.toExtend<LegacyArrayLikeObject<unknown>>();
expectTypeOf(UserExport.findLatest(1)).resolves.toEqualTypeOf<
  UserExport | undefined
>();
UserExport.findLatest("1");
// The serializer returns an empty object until the upload is attached.
UserExport.create({});
UserExport.create({
  id: 1,
  filename: "user-archive.zip",
  uri: "/uploads/short-url/archive.zip",
  filesize: 12345,
  extension: "zip",
  retain_hours: 47,
  human_filesize: "12.1 KB",
});
expectTypeOf(userExport.id).toEqualTypeOf<number | undefined>();
expectTypeOf(userExport.filename).toEqualTypeOf<string | undefined>();
expectTypeOf(userExport.uri).toEqualTypeOf<string | undefined>();
expectTypeOf(userExport.filesize).toEqualTypeOf<number | undefined>();
expectTypeOf(userExport.extension).toEqualTypeOf<string | null | undefined>();
expectTypeOf(userExport.retain_hours).toEqualTypeOf<number | undefined>();
expectTypeOf(userExport.human_filesize).toEqualTypeOf<string | undefined>();

declare const version: VersionCheck;
expectTypeOf(version).not.toExtend<EmberObject>();
expectTypeOf(version).not.toExtend<RestModel>();
expectTypeOf(version).not.toExtend<LegacyArrayLikeObject<unknown>>();
expectTypeOf(VersionCheck.find()).resolves.toEqualTypeOf<VersionCheck>();
expectTypeOf(new VersionCheck()).toEqualTypeOf<VersionCheck>();
expectTypeOf(
  new VersionCheck({
    installed_version: "2026.10.0-latest.1",
    installed_sha: "13d44d7b11f30806e0c0b55bfd81abff60f32e95",
    installed_describe: "v2026.10.0-latest.1 +6",
    git_branch: "main",
    updated_at: null,
    version_check_pending: true,
    stale_data: true,
  })
).toEqualTypeOf<VersionCheck>();
// The serializer emits null latest values; dashboard as_json can omit them.
expectTypeOf(
  new VersionCheck({
    installed_version: "2026.10.0-latest.1",
    installed_sha: null,
    installed_describe: "v2026.10.0-latest.1",
    latest_version: null,
    latest_pretty_version: null,
    latest_sha: null,
    missing_versions_count: null,
    updated_at: null,
  })
).toEqualTypeOf<VersionCheck>();
expectTypeOf(version.installed_version).toEqualTypeOf<string>();
expectTypeOf(version.installed_sha).toEqualTypeOf<string | null>();
expectTypeOf(version.installed_describe).toEqualTypeOf<string>();
expectTypeOf(version.git_branch).toEqualTypeOf<string | undefined>();
expectTypeOf(version.latest_version).toEqualTypeOf<string | null | undefined>();
expectTypeOf(version.latest_pretty_version).toEqualTypeOf<
  string | null | undefined
>();
expectTypeOf(version.latest_sha).toEqualTypeOf<string | null | undefined>();
expectTypeOf(version.missing_versions_count).toEqualTypeOf<
  number | null | undefined
>();
expectTypeOf(version.updated_at).toEqualTypeOf<string | null>();
expectTypeOf(version.version_check_pending).toEqualTypeOf<
  boolean | undefined
>();
expectTypeOf(version.stale_data).toEqualTypeOf<boolean | undefined>();
expectTypeOf(version.noCheckPerformed).toEqualTypeOf<boolean>();
expectTypeOf(version.upToDate).toEqualTypeOf<boolean>();
expectTypeOf(version.behindByOneVersion).toEqualTypeOf<boolean>();
expectTypeOf(version.gitLink).toEqualTypeOf<string | undefined>();
expectTypeOf(version.shortSha).toEqualTypeOf<string | undefined>();
expectTypeOf(version.latestGitLink).toEqualTypeOf<string | undefined>();
expectTypeOf(version.latestShortSha).toEqualTypeOf<string | undefined>();
expectTypeOf(version.changelogLink).toEqualTypeOf<string | undefined>();
expectTypeOf(version.installedCommitsAhead).toEqualTypeOf<number | undefined>();
expectTypeOf(version.latestCommitsAhead).toEqualTypeOf<number | undefined>();
expectTypeOf(version.newerCommitsAvailable).toEqualTypeOf<boolean>();
expectTypeOf(version.newChangesCount).toEqualTypeOf<number>();
// @ts-expect-error The abbreviated SHA is a getter, with no setter.
version.shortSha = "13d44d7b11";

declare const word: WatchedWord;
expectTypeOf<Omit<WatchedWord, "destroy">>().toExtend<
  Omit<EmberObject, "destroy">
>();
expectTypeOf(word).not.toExtend<RestModel>();
expectTypeOf(word).not.toExtend<LegacyArrayLikeObject<unknown>>();
WatchedWord.create({
  id: 1724,
  word: "bad",
  regexp: "(bad)",
  action: "block",
  case_sensitive: false,
  watched_word_group_id: null,
});
WatchedWord.create({
  id: 1725,
  word: "rep",
  regexp: "(rep)",
  replacement: "good",
  action: "replace",
  case_sensitive: false,
  watched_word_group_id: 10,
  html: true,
});
// Form-only camelCase fields are sent under different wire keys by save().
WatchedWord.create({
  words: ["first", "second"],
  replacement: null,
  replacementTags: [{ id: 1, name: "existing" }, { name: "new-tag" }],
  action: "tag",
  isCaseSensitive: false,
  isHtml: false,
}).save();
WatchedWord.create({
  words: ["replace"],
  replacement: "<b>replacement</b>",
  replacementTags: null,
  action: "replace",
  isCaseSensitive: true,
  isHtml: true,
});
expectTypeOf(word.id).toEqualTypeOf<number | undefined>();
expectTypeOf(word.word).toEqualTypeOf<string>();
expectTypeOf(word.regexp).toEqualTypeOf<string>();
expectTypeOf(word.action).toEqualTypeOf<WordAction>();
expectTypeOf(word.case_sensitive).toEqualTypeOf<boolean>();
expectTypeOf(word.watched_word_group_id).toEqualTypeOf<number | null>();
expectTypeOf(word.replacement).toEqualTypeOf<string | null | undefined>();
expectTypeOf(word.html).toEqualTypeOf<true | undefined>();
expectTypeOf(word.words).toEqualTypeOf<string[] | undefined>();
expectTypeOf(word.isCaseSensitive).toEqualTypeOf<boolean | undefined>();
expectTypeOf(word.isHtml).toEqualTypeOf<boolean | undefined>();
expectTypeOf(word.replacementTags).toEqualTypeOf<
  { id?: number; name: string }[] | null | undefined
>();
declare const groups: Awaited<ReturnType<typeof WatchedWord.findAll>>;
expectTypeOf(WatchedWord.findAll()).toExtend<Promise<typeof groups>>();
expectTypeOf(groups).not.toBeAny();
expectTypeOf(groups).toExtend<EmberObject[]>();
expectTypeOf(groups).not.toExtend<LegacyArrayLikeObject<unknown>>();
expectTypeOf(groups[0].nameKey).toEqualTypeOf<WordAction>();
expectTypeOf(groups[0].name).toEqualTypeOf<string>();
expectTypeOf(groups[0].words).toEqualTypeOf<WatchedWord[]>();
groups[0].words.push(word);
expectTypeOf(groups[0].compiledRegularExpression).toEqualTypeOf<
  Record<string, { case_sensitive: boolean }>[]
>();
declare const savedWords: Awaited<ReturnType<WatchedWord["save"]>>;
expectTypeOf(word.save()).toExtend<Promise<typeof savedWords>>();
expectTypeOf(savedWords).not.toBeAny();
expectTypeOf(savedWords.actions).toEqualTypeOf<WordAction[]>();
expectTypeOf(savedWords.compiled_regular_expressions).toEqualTypeOf<
  Partial<Record<WordAction, Record<string, { case_sensitive: boolean }>[]>>
>();
expectTypeOf(savedWords.words[0]).not.toExtend<EmberObject>();
expectTypeOf(savedWords.words[0].id).toEqualTypeOf<number>();
expectTypeOf(savedWords.words[0].word).toEqualTypeOf<string>();
expectTypeOf(savedWords.words[0].regexp).toEqualTypeOf<string>();
expectTypeOf(savedWords.words[0].replacement).toEqualTypeOf<
  string | null | undefined
>();
expectTypeOf(savedWords.words[0].action).toEqualTypeOf<WordAction>();
expectTypeOf(savedWords.words[0].case_sensitive).toEqualTypeOf<boolean>();
expectTypeOf(savedWords.words[0].watched_word_group_id).toEqualTypeOf<
  number | null
>();
expectTypeOf(savedWords.words[0].html).toEqualTypeOf<true | undefined>();
WatchedWord.create(savedWords.words[0]);
expectTypeOf(word.destroy()).resolves.toEqualTypeOf<{ success: string }>();
