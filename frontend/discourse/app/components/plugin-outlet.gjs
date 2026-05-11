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
 * `plugins/my-plugin/assets/javascripts/discourse/connectors/evil-trout/hello.gjs`
 *
 * ```gjs
 * <template><b>Hello World</b></template>
 * ```
 *
 * This will render `<b>Hello World</b>` in every `<PluginOutlet @name="evil-trout" />`.
 *
 * For wrapper outlets, use the `__before` and `__after` suffixes in the
 * connector directory name:
 *
 * `plugins/my-plugin/assets/javascripts/discourse/connectors/discovery-list-area__before/my-connector.gjs`
 * `plugins/my-plugin/assets/javascripts/discourse/connectors/discovery-list-area__after/my-connector.gjs`
 *
 * ## Args
 *
 * See {@link PluginOutletSignature} for the full list of accepted args.
 *
 * Notes:
 * - Use `deprecatedOutletArgument()` to build entries for `@deprecatedArgs`.
 * - For `@aliases`, an entry may be a plain string (non-deprecated alias)
 *   or a {@link PluginOutletAlias} object. Properties other than `name`,
 *   `position`, and `deprecated` are only valid when `deprecated` is true —
 *   a DEBUG-only assertion fires otherwise.
 * - The `id` on a {@link PluginOutletDeprecated} defaults to
 *   `discourse.plugin-outlet.deprecated.<name>` if omitted.
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
 * ### Merging a standalone outlet into a wrapper outlet's sub-outlet
 *
 * When a standalone outlet (e.g., `below-topic-list-item`) is being replaced by
 * a wrapper outlet, use `position="after"` (or `"before"`) to route connectors
 * from the old standalone outlet to the wrapper's `__after`/`__before`
 * sub-outlet:
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
 * sub-outlet instead, preserving the wrapped content. `position="before"`
 * works the same way for the `__before` sub-outlet.
 *
 * If the original standalone outlet declared a `@connectorTagName` (so that
 * legacy `.hbs` connectors received an automatic wrapper element), preserve
 * that behavior on the alias so existing connectors keep their wrapper:
 *
 * ```handlebars
 * <PluginOutlet
 *   @name="latest-topic-list-item__post-count"
 *   @aliases={{array
 *     (hash
 *       name="above-latest-topic-list-item-post-count"
 *       position="before"
 *       connectorTagName="div"
 *       deprecated=true
 *       since="2026.3.0"
 *     )
 *   }}
 * />
 * ```
 *
 * `connectorTagName` only applies to legacy file-based connectors registered
 * under the aliased name. Modern `.gjs` connectors control their own DOM and
 * ignore it.
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
 * ### Deprecating an individual outlet argument
 *
 * Use `@deprecatedArgs` with `deprecatedOutletArgument()` to warn when a
 * specific arg is read by a connector, while keeping it functional until
 * connectors are migrated:
 *
 * ```gjs
 * import deprecatedOutletArgument from "discourse/helpers/deprecated-outlet-argument";
 *
 * <template>
 *   <PluginOutlet
 *     @name="my-outlet"
 *     @outletArgs={{lazyHash newName=this.newName}}
 *     @deprecatedArgs={{lazyHash
 *       oldName=(deprecatedOutletArgument
 *         value=this.newName
 *         message="`oldName` is deprecated, use `newName` instead."
 *         since="2026.3.0"
 *       )
 *     }}
 *   />
 * </template>
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

/**
 * @typedef PluginOutletAlias
 *
 * @property {string} name The alias outlet name.
 * @property {boolean} [deprecated] Marks this alias as deprecated.
 * @property {"before"|"after"} [position] Routes the alias to a wrapper sub-outlet.
 * @property {string} [since] Discourse version when the deprecation was introduced.
 * @property {string} [message] Custom deprecation message.
 * @property {string} [id] Deprecation ID for silencing (auto-generated if omitted).
 * @property {string} [url] URL with more detail about the deprecation.
 * @property {boolean} [raiseError] Whether to throw instead of warn.
 * @property {string} [connectorTagName] HTML tag for legacy file-based connector
 *   wrapper (e.g. `"div"`, `"span"`). Only relevant for position-targeted aliases
 *   merging standalone outlets that had `@connectorTagName`.
 */

/**
 * @typedef PluginOutletDeprecated
 *
 * @property {string} [since] Version when the outlet was deprecated.
 * @property {string} [message] Custom deprecation message.
 * @property {string} [id] Deprecation ID.
 * @property {string} [url] URL with more detail about the deprecation.
 * @property {boolean} [raiseError] Whether to throw instead of warn.
 */

/**
 * @typedef PluginOutletSignature
 *
 * @property {object} Args
 *
 * // Identity
 * @property {string} Args.name The outlet identifier. Connectors registered
 *   under this name will be rendered here.
 *
 * // Args passed to connectors
 * @property {object} [Args.outletArgs] Arguments passed to connectors rendered
 *   in this outlet.
 * @property {object} [Args.deprecatedArgs] Args with per-access deprecation
 *   warnings. Build entries with `deprecatedOutletArgument()`.
 * @property {object} [Args.args] Deprecated legacy alias for `outletArgs`.
 *
 * // Aliases & deprecation
 * @property {Array<string|PluginOutletAlias>} [Args.aliases] Alternative outlet
 *   names that this outlet also resolves connectors from. Useful for renaming
 *   or merging outlets without breaking existing customizations.
 * @property {PluginOutletDeprecated} [Args.deprecated] Marks this outlet itself
 *   as deprecated. When set, a deprecation warning is emitted if any connectors
 *   are registered for this outlet.
 *
 * // Legacy file-based connector rendering
 * @property {string} [Args.tagName] HTML tag for the wrapper element rendered
 *   around legacy file-based connectors.
 * @property {string} [Args.connectorTagName] HTML tag for legacy file-based
 *   connector wrappers (e.g. `"div"`, `"span"`).
 * @property {boolean} [Args.defaultGlimmer] When true, file-based connectors
 *   are rendered as template-only Glimmer components (no `this` context).
 *
 * // Optional wrapped content (wrapper outlets)
 * @property {object} Blocks
 * @property {[]} Blocks.default Default content rendered when no connector
 *   replaces it.
 */

/** @extends {Component<PluginOutletSignature>} */
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

  /**
   * The connector tag name inherited from a position-targeted alias routed
   * to the `__before` sub-outlet. Preserves the old standalone outlet's
   * `@connectorTagName` for legacy file-based connectors.
   *
   * @returns {string|undefined}
   */
  @cached
  get connectorTagNameForBefore() {
    for (const alias of this.normalizedAliases) {
      if (alias.position === "before" && alias.connectorTagName) {
        return alias.connectorTagName;
      }
    }
    return undefined;
  }

  /**
   * The connector tag name inherited from a position-targeted alias routed
   * to the `__after` sub-outlet. Preserves the old standalone outlet's
   * `@connectorTagName` for legacy file-based connectors.
   *
   * @returns {string|undefined}
   */
  @cached
  get connectorTagNameForAfter() {
    for (const alias of this.normalizedAliases) {
      if (alias.position === "after" && alias.connectorTagName) {
        return alias.connectorTagName;
      }
    }
    return undefined;
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
          @connectorTagName={{this.connectorTagNameForBefore}}
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
          @connectorTagName={{this.connectorTagNameForAfter}}
          @outletArgs={{this.outletArgsWithDeprecations}}
        />
      {{~/if~}}
    {{~else~}}
      {{yield}}
    {{~/if~}}
  </template>
}
