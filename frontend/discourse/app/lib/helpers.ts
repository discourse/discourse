import Helper from "@ember/component/helper";
import type { RegisterOptions } from "@ember/owner";
import { dasherize } from "@ember/string";
import { trustHTML } from "@ember/template";
import deprecated from "discourse/lib/deprecated";
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

export function htmlHelper(fn: (...args: unknown[]) => unknown) {
  deprecated(
    `htmlHelper is deprecated. Use a plain function and \`htmlSafe()\` from "@ember/template" instead.`,
    { id: "discourse.html-helper" }
  );

  return Helper.helper(function (this: unknown, ...args: unknown[]) {
    args =
      args.length > 1
        ? (args[0] as unknown[]).concat({ hash: args[args.length - 1] })
        : args;
    return trustHTML((fn.apply(this, args) || "") as string);
  });
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

/**
 * Register a helper for Ember and raw-hbs. This exists for
 * legacy reasons, and should be avoided in new code. Instead, you should
 * do `export default ...` from a `helpers/*.js` file.
 */
export function registerUnbound(
  name: string,
  fn: (...args: unknown[]) => unknown
) {
  deprecated(
    `[registerUnbound ${name}] registerUnbound is deprecated. Instead, you should export a default function from 'discourse/helpers/${name}.js'.`,
    { id: "discourse.register-unbound" }
  );

  _helpers[name] = class extends Helper {
    compute(params: unknown[], args: unknown) {
      return fn(...params, args);
    }
  };
}

/**
 * Register a helper for raw-hbs only
 */
export function registerRawHelper(name: string) {
  deprecated(
    `[registerRawHelper ${name}] the raw handlebars system has been removed, so calls to registerRawHelper should be removed.`,
    { id: "discourse.register-raw-helper" }
  );
}
