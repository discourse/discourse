import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import ClassicComponent from "@ember/component";
import { concat } from "@ember/helper";
import { get } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import curryComponent from "ember-curry-component";
import { or } from "truth-helpers";
import PluginConnector from "discourse/components/plugin-connector";
import PluginOutlet from "discourse/components/plugin-outlet";
import { bind } from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
import { helperContext } from "discourse/lib/helpers";
import {
  buildArgsWithDeprecations,
  connectorsExist,
  renderedConnectorsFor,
} from "discourse/lib/plugin-connectors";

const GET_DEPRECATION_MSG =
  "Plugin outlet context is no longer an EmberObject - using `get()` is deprecated.";
const ARGS_DEPRECATION_MSG =
  "PluginOutlet arguments should now be passed using `@outletArgs=` instead of `@args=`";

/**
   A plugin outlet is an extension point for templates where other templates can
   be inserted by plugins.

   ## Usage

   If your handlebars template has:

   ```handlebars
     <PluginOutlet @name="evil-trout" />
   ```

   Then any handlebars files you create in the `connectors/evil-trout` directory
   will automatically be appended. For example:

   plugins/hello/assets/javascripts/discourse/templates/connectors/evil-trout/hello.hbs

   With the contents:

   ```handlebars
     <b>Hello World</b>
   ```

   Will insert <b>Hello World</b> at that point in the template.

**/

export default class PluginOutletComponent extends Component {
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

  @bind
  getConnectors({ hasBlock } = {}) {
    const connectors = renderedConnectorsFor(
      this.args.name,
      this.outletArgsWithDeprecations,
      this.context,
      getOwner(this)
    );
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
    return (
      connectorsExist(this.args.name) ||
      (hasBlock &&
        (connectorsExist(this.args.name + "__before") ||
          connectorsExist(this.args.name + "__after")))
    );
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

  <template>
    {{~#if (this.connectorsExist hasBlock=(has-block))~}}
      {{~#if (has-block)~}}
        <PluginOutlet
          @name={{concat @name "__before"}}
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
          @outletArgs={{this.outletArgsWithDeprecations}}
        />
      {{~/if~}}
    {{~else~}}
      {{yield}}
    {{~/if~}}
  </template>
}
