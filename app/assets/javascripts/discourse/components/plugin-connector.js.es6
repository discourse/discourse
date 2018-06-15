import { observes } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  init() {
    this._super();

    const connector = this.get("connector");
    this.set("layoutName", connector.templateName);

    const args = this.get("args") || {};
    Object.keys(args).forEach(key => this.set(key, args[key]));

    const connectorClass = this.get("connector.connectorClass");
    connectorClass.setupComponent.call(this, args, this);
  },

  @observes("args")
  _argsChanged() {
    const args = this.get("args") || {};
    Object.keys(args).forEach(key => this.set(key, args[key]));
  },

  send(name, ...args) {
    const connectorClass = this.get("connector.connectorClass");
    const action = connectorClass.actions[name];
    return action ? action.call(this, ...args) : this._super(name, ...args);
  }
});
