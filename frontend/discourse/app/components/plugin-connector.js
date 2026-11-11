/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { computed, defineProperty } from "@ember/object";
import {
  buildArgsWithDeprecations,
  deprecatedArgumentValue,
} from "discourse/lib/outlet-args";

export default class PluginConnector extends Component {
  init() {
    super.init(...arguments);

    if (this.args) {
      Object.keys(this.args).forEach((key) => {
        defineProperty(
          this,
          key,
          computed(`args.${key}`, function () {
            return this.args[key];
          })
        );
      });
    }

    const connectorInfo = {
      outletName: this.connector?.outletName,
      connectorName: this.connector?.connectorName,
      classModuleName: this.connector?.classModuleName,
      templateModule: this.connector?.templateModule,
      layoutName: this.layoutName,
    };

    if (this.deprecatedArgs) {
      Object.keys(this.deprecatedArgs).forEach((key) => {
        defineProperty(
          this,
          key,
          computed("deprecatedArgs", function () {
            return deprecatedArgumentValue(this.deprecatedArgs[key], {
              ...connectorInfo,
              argumentName: key,
            });
          })
        );
      });
    }

    const connectorClass = this.connector.connectorClass;
    this.set("actions", connectorClass?.actions);

    if (this.actions) {
      for (const [name, action] of Object.entries(this.actions)) {
        this.set(name, action.bind(this));
      }
    }

    const merged = buildArgsWithDeprecations(
      this.args,
      this.deprecatedArgs,
      connectorInfo
    );
    connectorClass?.setupComponent?.call(this, merged, this);
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    const connectorClass = this.connector.connectorClass;
    connectorClass?.teardownComponent?.call(this, this);
  }

  send(name, ...args) {
    const connectorClass = this.connector.connectorClass;
    const action = connectorClass?.actions?.[name];
    return action ? action.call(this, ...args) : super.send(name, ...args);
  }
}
