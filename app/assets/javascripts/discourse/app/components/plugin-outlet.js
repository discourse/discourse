import GlimmerComponentWithDeprecatedParentView from "discourse/components/glimmer-component-with-deprecated-parent-view";
import ClassicComponent from "@ember/component";

import {
  buildArgsWithDeprecations,
  connectorsExist,
  renderedConnectorsFor,
} from "discourse/lib/plugin-connectors";
import { helperContext } from "discourse-common/lib/helpers";
import deprecated from "discourse-common/lib/deprecated";
import { get } from "@ember/object";
import { cached } from "@glimmer/tracking";
import { bind } from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";

const PARENT_VIEW_DEPRECATION_MSG =
  "parentView should not be used within plugin outlets. Use the available outlet arguments, or inject a service which can provide the context you need.";
const GET_DEPRECATION_MSG =
  "Plugin outlet context is no longer an EmberObject - using `get()` is deprecated.";
const TAG_NAME_DEPRECATION_MSG =
  "The `tagName` argument to PluginOutlet is deprecated. If a wrapper element is required, define it manually around the outlet call. Using tagName will prevent wrapper PluginOutlets from functioning correctly.";
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

export default class PluginOutletComponent extends GlimmerComponentWithDeprecatedParentView {
  @service clientErrorHandler;

  context = {
    ...helperContext(),
    get parentView() {
      return this.parentView;
    },
    get() {
      deprecated(GET_DEPRECATION_MSG, {
        id: "discourse.plugin-outlet-context-get",
      });
      return get(this, ...arguments);
    },
  };

  constructor() {
    const result = super(...arguments);

    if (this.args.tagName) {
      deprecated(`${TAG_NAME_DEPRECATION_MSG} (outlet: ${this.args.name})`, {
        id: "discourse.plugin-outlet-tag-name",
      });
    }

    if (this.args.args) {
      deprecated(`${ARGS_DEPRECATION_MSG} (outlet: ${this.args.name})`, {
        id: "discourse.plugin-outlet-args",
      });
    }

    return result;
  }

  @bind
  getConnectors({ hasBlock }) {
    const connectors = renderedConnectorsFor(
      this.args.name,
      this.outletArgsWithDeprecations,
      this.context
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

  get connectorsExist() {
    return connectorsExist(this.args.name);
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
      this.args.deprecatedArgs || {}
    );
  }

  get parentView() {
    deprecated(`${PARENT_VIEW_DEPRECATION_MSG} (outlet: ${this.args.name})`, {
      id: "discourse.plugin-outlet-parent-view",
    });
    return this._parentView;
  }
  set parentView(value) {
    this._parentView = value;
  }

  // Older plugin outlets have a `tagName` which we need to preserve for backwards-compatibility
  get wrapperComponent() {
    return PluginOutletWithTagNameWrapper;
  }
}

class PluginOutletWithTagNameWrapper extends ClassicComponent {
  // Overridden parentView to make this wrapper 'transparent'
  // Calling this will trigger the deprecation notice in PluginOutletComponent
  get parentView() {
    return this._parentView.parentView;
  }
  set parentView(value) {
    this._parentView = value;
  }
}
