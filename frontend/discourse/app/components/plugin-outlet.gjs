/* eslint-disable ember/no-classic-components */
import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { cached } from "@glimmer/tracking";
import ClassicComponent from "@ember/component";
import { concat } from "@ember/helper";
import { get } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import curryComponent from "ember-curry-component";
import PluginConnector from "discourse/components/plugin-connector";
import { bind } from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
import { helperContext } from "discourse/lib/helpers";
import { buildArgsWithDeprecations } from "discourse/lib/outlet-args";
import {
  connectorsExist,
  renderedConnectorsFor,
} from "discourse/lib/plugin-connectors";
import { or } from "discourse/truth-helpers";

const GET_DEPRECATION_MSG =
  "Plugin outlet context is no longer an EmberObject - using `get()` is deprecated.";
const ARGS_DEPRECATION_MSG =
  "PluginOutlet arguments should now be passed using `@outletArgs=` instead of `@args=`";

const DEPRECATION_ONLY_KEYS = ["since", "message", "id", "url", "raiseError"];
const VALID_POSITIONS = ["before", "after"];

/**
 * Normalizes an alias entry to a consistent object form.
 * Accepts either a plain string or an object with a `name` property.
 *
 * @param {string|Object} alias - The alias entry to normalize.
 * @returns {{ name: string, deprecated?: boolean, position?: string, since?: string, message?: string, id?: string, url?: string, raiseError?: boolean }}
 */
export function normalizeAlias(alias) {
  if (typeof alias === "string") {
    return { name: alias };
  }

  if (DEBUG) {
    if (!alias.name) {
      throw new Error("PluginOutlet alias object must have a `name` property.");
    }

    if (alias.position && !VALID_POSITIONS.includes(alias.position)) {
      throw new Error(
        `PluginOutlet alias "${alias.name}" has invalid position "${alias.position}". ` +
          `Valid values are: ${VALID_POSITIONS.join(", ")}.`
      );
    }

    if (!alias.deprecated) {
      const presentKeys = DEPRECATION_ONLY_KEYS.filter(
        (key) => alias[key] != null
      );
      if (presentKeys.length > 0) {
        throw new Error(
          `PluginOutlet alias "${alias.name}" has deprecation properties (${presentKeys.join(", ")}) but \`deprecated\` is not true. ` +
            `Set \`deprecated=true\` or remove these properties.`
        );
      }
    }
  }

  return alias;
}

/**
 * A plugin outlet is an extension point for templates where other templates can
 * be inserted by plugins.
 *
 * ## Standard vs wrapper outlets
 *
 * A **standard outlet** is an empty slot where connectors are inserted:
 *
 * ```handlebars
 * <PluginOutlet @name="above-footer" />
 * ```
 *
 * A **wrapper outlet** wraps existing content by providing a block. When a
 * connector is registered, it replaces the wrapped content. The outlet also
 * automatically creates `__before` and `__after` sub-outlets that allow
 * multiple connectors to render before or after the wrapped content without
 * replacing it:
 *
 * ```handlebars
 * <PluginOutlet @name="discovery-list-area">
 *   <div class="default-content">This is the default content</div>
 * </PluginOutlet>
 * ```
 *
 * In this example, connectors can target:
 * - `discovery-list-area` to replace the default content
 * - `discovery-list-area__before` to render before it
 * - `discovery-list-area__after` to render after it
 *
 * ## Rendering connectors
 *
 * There are two ways to render content in a plugin outlet:
 *
 * ### 1. Plugin API (`api.renderInOutlet`)
 *
 * Register a component programmatically using the Plugin API:
 *
 * ```javascript
 * import MyComponent from "discourse/plugins/my-plugin/components/my-component";
 * api.renderInOutlet("evil-trout", MyComponent);
 * ```
 *
 * Or inline with gjs:
 *
 * ```javascript
 * api.renderInOutlet("evil-trout", <template><b>Hello World</b></template>);
 * ```
 *
 * For wrapper outlets, use `api.renderBeforeWrapperOutlet()` and
 * `api.renderAfterWrapperOutlet()` to render content before or after the
 * wrapped content without replacing it:
 *
 * ```javascript
 * api.renderBeforeWrapperOutlet("discovery-list-area", BeforeComponent);
 * api.renderAfterWrapperOutlet("discovery-list-area", AfterComponent);
 * ```
 *
 * ### 2. File-based connectors
 *
 * Create a template file in the `connectors/<outlet-name>/` directory:
 *
 * `plugins/my-plugin/assets/javascripts/discourse/connectors/evil-trout/hello.hbs`
 *
 * ```handlebars
 * <b>Hello World</b>
 * ```
 *
 * This will render `<b>Hello World</b>` in every `<PluginOutlet @name="evil-trout" />`.
 *
 * For wrapper outlets, use the `__before` and `__after` suffixes in the
 * connector directory name:
 *
 * `plugins/my-plugin/assets/javascripts/discourse/connectors/discovery-list-area__before/my-connector.hbs`
 * `plugins/my-plugin/assets/javascripts/discourse/connectors/discovery-list-area__after/my-connector.hbs`
 *
 * ## Args
 *
 * @param {string} name - The outlet identifier. Connectors registered under this name
 *   will be rendered here.
 * @param {Object} [outletArgs] - Arguments passed to connectors rendered in this outlet.
 * @param {Object} [deprecatedArgs] - Deprecated args with per-access deprecation warnings.
 *   Use `deprecatedOutletArgument()` helper to create entries.
 * @param {Array<string|Object>} [aliases] - Alternative outlet names that this outlet
 *   also resolves connectors from. Useful for renaming or merging outlets without breaking
 *   existing customizations. Each entry can be:
 *   - A plain string for a non-deprecated alias
 *   - An object with properties described below for deprecated or position-targeted aliases
 * @param {Object} [deprecated] - Marks this outlet itself as deprecated. When set, a
 *   deprecation warning is emitted if any connectors are registered for this outlet.
 *
 * ## Alias object properties
 *
 * When an alias entry is an object, it supports the following properties:
 *
 * | Property     | Type    | Required | Description |
 * |-------------|---------|----------|-------------|
 * | `name`       | string  | yes      | The alias outlet name |
 * | `deprecated` | boolean | no       | Marks this alias as deprecated |
 * | `position`   | string  | no       | Routes alias to a wrapper sub-outlet: `"before"` or `"after"` |
 * | `since`      | string  | no       | Discourse version when deprecation was introduced |
 * | `message`    | string  | no       | Custom deprecation message |
 * | `id`         | string  | no       | Deprecation ID for silencing (auto-generated if omitted) |
 * | `url`        | string  | no       | URL with more detail about the deprecation |
 * | `raiseError` | boolean | no       | Whether to throw instead of warn |
 *
 * Note: `since`, `message`, `id`, `url`, and `raiseError` are only valid when
 * `deprecated` is `true`. A DEBUG-only assertion will fire if they are set without it.
 *
 * ## Deprecated hash properties (for `@deprecated` arg)
 *
 * | Property     | Type    | Description |
 * |-------------|---------|-------------|
 * | `since`      | string  | Version when the outlet was deprecated |
 * | `message`    | string  | Custom deprecation message |
 * | `id`         | string  | Deprecation ID (auto-generated: `discourse.plugin-outlet.deprecated.<name>`) |
 * | `url`        | string  | URL for details |
 * | `raiseError` | boolean | Whether to throw instead of warn |
 *
 * ## Examples
 *
 * ### Renaming an outlet (old name is deprecated)
 *
 * ```handlebars
 * <PluginOutlet
 *   @name="new-outlet-name"
 *   @aliases={{array
 *     (hash name="old-outlet-name" deprecated=true since="2026.3.0")
 *   }}
 *   @outletArgs={{this.outletArgs}}
 * />
 * ```
 *
 * Connectors registered under `old-outlet-name` will render here and emit
 * a deprecation warning pointing to `new-outlet-name`.
 *
 * ### Non-deprecated alias
 *
 * ```handlebars
 * <PluginOutlet
 *   @name="canonical-name"
 *   @aliases={{array "alternate-name"}}
 * />
 * ```
 *
 * ### Merging a standalone outlet into a wrapper outlet's after slot
 *
 * When a standalone outlet (e.g., `below-topic-list-item`) is being replaced by
 * a wrapper outlet, use `position="after"` to route connectors from the old
 * standalone outlet to the wrapper's `__after` sub-outlet:
 *
 * ```handlebars
 * <PluginOutlet
 *   @name="topic-list-item__main-link-bottom-row"
 *   @aliases={{array
 *     (hash
 *       name="below-topic-list-item-bottom-row"
 *       position="after"
 *       deprecated=true
 *       since="2026.3.0"
 *     )
 *   }}
 * >
 *   ...wrapped content...
 * </PluginOutlet>
 * ```
 *
 * Without `position`, alias connectors render in the main outlet (replacing
 * wrapped content). With `position="after"`, they render in the `__after`
 * sub-outlet instead, preserving the wrapped content.
 *
 * ### Deprecating an outlet entirely
 *
 * ```handlebars
 * <PluginOutlet
 *   @name="doomed-outlet"
 *   @deprecated={{hash since="2026.3.0" message="Use the Block API instead."}}
 * />
 * ```
 *
 * ## Wrapper outlet alias behavior
 *
 * When a wrapper outlet has aliases, the `__before` and `__after` sub-outlets
 * automatically inherit them. For example, if outlet `foo` has alias `bar`,
 * then connectors registered under `bar__before` will render in `foo__before`,
 * and `bar__after` in `foo__after`.
 *
 * Aliases with a `position` property are an exception: they are routed to
 * the specified sub-outlet using their base name (not appended with
 * `__before`/`__after`), allowing standalone outlets to be merged into
 * a wrapper outlet's before or after slot.
 */

export default class PluginOutlet extends Component {
  @service clientErrorHandler;

  context = {
    ...helperContext(),
    get() {
      deprecated(GET_DEPRECATION_MSG, {
        id: "discourse.plugin-outlet-context-get",
      });
      return get(this, ...arguments);
    },
  };

  constructor() {
    const result = super(...arguments);

    if (this.args.args) {
      deprecated(`${ARGS_DEPRECATION_MSG} (outlet: ${this.args.name})`, {
        id: "discourse.plugin-outlet-args",
      });
    }

    return result;
  }

  /**
   * Normalized alias entries from @aliases arg.
   * Each entry is an object with at least a `name` property.
   *
   * @returns {Array<{ name: string, deprecated?: boolean, since?: string, message?: string, id?: string, url?: string, raiseError?: boolean }>}
   */
  @cached
  get normalizedAliases() {
    if (!this.args.aliases?.length) {
      return [];
    }
    return this.args.aliases.map(normalizeAlias);
  }

  /**
   * Derived aliases for the __before sub-outlet.
   * Includes aliases with `position: "before"` using their base name (for merging
   * standalone outlets into a wrapper's before slot), plus `__before` variants
   * of all aliases without a position (for inheriting wrapper sub-outlet connectors).
   *
   * @returns {Array<Object>}
   */
  @cached
  get aliasesForBefore() {
    const result = [];
    for (const alias of this.normalizedAliases) {
      if (alias.position === "before") {
        // Strip position since routing is resolved -- the sub-outlet
        // should treat this as a regular alias
        const withoutPosition = { ...alias };
        delete withoutPosition.position;
        result.push(withoutPosition);
      } else if (!alias.position) {
        result.push({ ...alias, name: `${alias.name}__before` });
      }
    }
    return result;
  }

  /**
   * Derived aliases for the __after sub-outlet.
   * Includes aliases with `position: "after"` using their base name (for merging
   * standalone outlets into a wrapper's after slot), plus `__after` variants
   * of all aliases without a position (for inheriting wrapper sub-outlet connectors).
   *
   * @returns {Array<Object>}
   */
  @cached
  get aliasesForAfter() {
    const result = [];
    for (const alias of this.normalizedAliases) {
      if (alias.position === "after") {
        const withoutPosition = { ...alias };
        delete withoutPosition.position;
        result.push(withoutPosition);
      } else if (!alias.position) {
        result.push({ ...alias, name: `${alias.name}__after` });
      }
    }
    return result;
  }

  @bind
  getConnectors({ hasBlock } = {}) {
    const aliases = this.normalizedAliases;
    const dep = this.args.deprecated;

    const connectors = this.#renderedConnectorsFor(this.args.name, {
      aliases,
      deprecated: dep,
    });

    // Emit outlet-level deprecation if connectors exist
    if (dep && connectors.length > 0) {
      this.#emitOutletDeprecation();
    }

    // Collect connectors from aliases (skip position-targeted aliases,
    // they are handled by the __before/__after sub-outlets)
    for (const alias of aliases) {
      if (alias.position) {
        continue;
      }
      const aliasConnectors = this.#renderedConnectorsFor(alias.name, {
        skipDebug: true,
      });
      if (aliasConnectors.length > 0) {
        if (alias.deprecated) {
          this.#emitAliasDeprecation(alias);
        }
        connectors.push(...aliasConnectors);
      }
    }

    if (connectors.length > 1 && hasBlock) {
      const message = `Multiple connectors were registered for the ${this.args.name} outlet. Using the first.`;
      this.clientErrorHandler.displayErrorNotice(message);
      // eslint-disable-next-line no-console
      console.error(
        message,
        connectors.map((c) => c.humanReadableName)
      );
      return [connectors[0]];
    }
    return connectors;
  }

  @bind
  connectorsExist({ hasBlock } = {}) {
    if (
      this.#connectorsExistFor(this.args.name) ||
      (hasBlock &&
        (this.#connectorsExistFor(this.args.name + "__before") ||
          this.#connectorsExistFor(this.args.name + "__after")))
    ) {
      return true;
    }

    // Check aliases (position-targeted aliases are checked by sub-outlets,
    // but we still need to consider them for the wrapper's connectorsExist
    // since they make the wrapper render its content including sub-outlets)
    for (const alias of this.normalizedAliases) {
      if (alias.position) {
        if (this.#connectorsExistFor(alias.name)) {
          return true;
        }
        continue;
      }
      if (
        this.#connectorsExistFor(alias.name) ||
        (hasBlock &&
          (this.#connectorsExistFor(alias.name + "__before") ||
            this.#connectorsExistFor(alias.name + "__after")))
      ) {
        return true;
      }
    }

    return false;
  }

  // Traditionally, pluginOutlets had an argument named 'args'. However, that name is reserved
  // in recent versions of ember so we need to migrate to outletArgs
  @cached
  get outletArgs() {
    return this.args.outletArgs || this.args.args || {};
  }

  @cached
  get outletArgsWithDeprecations() {
    if (!this.args.deprecatedArgs) {
      return this.outletArgs;
    }

    return buildArgsWithDeprecations(
      this.outletArgs,
      this.args.deprecatedArgs || {},
      { outletName: this.args.name }
    );
  }

  @bind
  safeCurryComponent(component, args) {
    if (component.prototype instanceof ClassicComponent) {
      for (const arg of Object.keys(args)) {
        if (component.prototype.hasOwnProperty(arg)) {
          deprecated(
            `Unable to set @${arg} on connector for ${this.args.name}, because a property on the component class clashes with the argument name. Resolve the clash, or convert to a glimmer component.`,
            {
              id: "discourse.plugin-outlet-classic-args-clash",
            }
          );

          // Build a clone of `args`, without the offending key, while preserving getters
          const descriptors = Object.getOwnPropertyDescriptors(args);
          delete descriptors[arg];
          args = Object.defineProperties({}, descriptors);
        }
      }
    }

    return curryComponent(component, args, getOwner(this));
  }

  #connectorsExistFor(name) {
    return connectorsExist(name);
  }

  #emitAliasDeprecation(alias) {
    const message =
      alias.message ||
      `Plugin outlet "${alias.name}" has been renamed to "${this.args.name}". Update your connector to use the new name.`;

    deprecated(message, {
      id: alias.id || `discourse.plugin-outlet.alias.${alias.name}`,
      since: alias.since,
      url: alias.url,
      raiseError: alias.raiseError,
    });
  }

  #emitOutletDeprecation() {
    const dep = this.args.deprecated;
    const message =
      dep.message ||
      `Plugin outlet "${this.args.name}" is deprecated and will be removed in a future version.`;

    deprecated(message, {
      id: dep.id || `discourse.plugin-outlet.deprecated.${this.args.name}`,
      since: dep.since,
      url: dep.url,
      raiseError: dep.raiseError,
    });
  }

  #renderedConnectorsFor(name, options) {
    return renderedConnectorsFor(
      name,
      this.outletArgsWithDeprecations,
      this.context,
      getOwner(this),
      options
    );
  }

  <template>
    {{~#if (this.connectorsExist hasBlock=(has-block))~}}
      {{~#if (has-block)~}}
        <PluginOutlet
          @name={{concat @name "__before"}}
          @aliases={{this.aliasesForBefore}}
          @outletArgs={{this.outletArgsWithDeprecations}}
        />
      {{~/if~}}

      {{~#each (this.getConnectors hasBlock=(has-block)) as |c|~}}
        {{~#if c.componentClass~}}
          {{~#let
            (this.safeCurryComponent
              c.componentClass this.outletArgsWithDeprecations
            )
            as |CurriedComponent|
          ~}}
            <CurriedComponent
              @outletArgs={{this.outletArgsWithDeprecations}}
            >{{yield}}</CurriedComponent>
          {{~/let~}}
        {{~else if @defaultGlimmer~}}
          <c.templateOnly
            @outletArgs={{this.outletArgsWithDeprecations}}
          >{{yield}}</c.templateOnly>
        {{~else~}}
          <PluginConnector
            @connector={{c}}
            @args={{this.outletArgs}}
            @deprecatedArgs={{@deprecatedArgs}}
            @outletArgs={{this.outletArgsWithDeprecations}}
            @tagName={{or @connectorTagName ""}}
            @layout={{c.template}}
            class={{c.classicClassNames}}
          >{{yield}}</PluginConnector>
        {{~/if~}}
      {{~else~}}
        {{yield}}
      {{~/each~}}

      {{~#if (has-block)~}}
        <PluginOutlet
          @name={{concat @name "__after"}}
          @aliases={{this.aliasesForAfter}}
          @outletArgs={{this.outletArgsWithDeprecations}}
        />
      {{~/if~}}
    {{~else~}}
      {{yield}}
    {{~/if~}}
  </template>
}
