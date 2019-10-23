import Component from "@ember/component";
import { observes } from "ember-addons/ember-computed-decorators";

export default Component.extend({
  init() {
    this._super(...arguments);

    const connector = this.connector;
    this.set("layoutName", connector.templateName);

    const args = this.args || {};
    Object.keys(args).forEach(key => this.set(key, args[key]));

    const connectorClass = this.get("connector.connectorClass");
    connectorClass.setupComponent.call(this, args, this);

    this.set("actions", connectorClass.actions);
  },

  willDestroyElement() {
    this._super(...arguments);

    const connectorClass = this.get("connector.connectorClass");
    connectorClass.teardownComponent.call(this, this);
  },

  @observes("args")
  _argsChanged() {
    const args = this.args || {};
    Object.keys(args).forEach(key => this.set(key, args[key]));
  },

  send(name, ...args) {
    const connectorClass = this.get("connector.connectorClass");
    const action = connectorClass.actions[name];
    return action ? action.call(this, ...args) : this._super(name, ...args);
  }
});
