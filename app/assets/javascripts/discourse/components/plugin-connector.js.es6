export default Ember.Component.extend({

  init() {
    this._super();

    const connector = this.get('connector');
    this.set('layoutName', connector.templateName);

    const args = this.get('args') || {};
    Object.keys(args).forEach(key => this.set(key, args[key]));
  },

  send(name, ...args) {
    const connectorClass = this.get('connector.connectorClass');
    const action = connectorClass.actions[name];
    return action ? action.call(this, ...args) : this._super(name, ...args);
  }

});
