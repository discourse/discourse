import Helper from "@ember/component/helper";
import type { RegisterOptions } from "@ember/owner";
import { dasherize } from "@ember/string";
import type Session from "discourse/models/session";
import type Site from "discourse/models/site";
import type TopicTrackingState from "discourse/models/topic-tracking-state";
import type User from "discourse/models/user";
import type Capabilities from "discourse/services/capabilities";
import type KeyValueStore from "discourse/services/key-value-store";
import type SiteSettings from "discourse/services/site-settings";

/**
 * Returns a value as an array. Only `null` and `undefined` give an empty
 * array, so falsy values like `""` and `0` are kept.
 */
export function makeArray<T>(obj: T | T[] | null | undefined): T[] {
  if (obj === null || obj === undefined) {
    return [];
  }
  return Array.isArray(obj) ? obj : [obj];
}

/** The subset of the owner's registry {@link registerHelpers} writes into. */
export interface HelperRegistry {
  register(fullName: string, factory: unknown, options?: RegisterOptions): void;
}

/**
 * What a legacy helper reads through {@link helperContext}. Such helpers run
 * without an owner, so they cannot inject any of it themselves.
 */
export interface HelperContext {
  siteSettings: SiteSettings;
  keyValueStore: KeyValueStore;
  capabilities: Capabilities;
  currentUser: User | null;
  site: Site;
  session: Session;
  topicTrackingState: TopicTrackingState;
  registry: HelperRegistry;
}

const _helpers: Record<string, unknown> = {};

export function registerHelper(
  name: string,
  fn: (...args: unknown[]) => unknown
) {
  _helpers[name] = Helper.helper(fn);
}

export function findHelper(name: string) {
  return _helpers[name] || _helpers[dasherize(name)];
}

export function registerHelpers(registry: HelperRegistry) {
  Object.keys(_helpers).forEach((name) => {
    registry.register(`helper:${name}`, _helpers[name], { singleton: false });
  });
}

let _helperContext: HelperContext;
export function createHelperContext(ctx: HelperContext) {
  _helperContext = ctx;
}

/**
 * The context a legacy helper reads instead of injecting services. Nothing
 * outside helpers, and the lib code they call, should use it.
 */
export function helperContext() {
  return _helperContext;
}
