export default Ember.View.extend({
  attributeBindings: ['style'],
  _containedView: null,
  _scheduled: null,

  init: function() {
    this._super();
    this._scheduled = false;
    this._childViews = [];
  },

  setContainedView(cv) {
    if (this._childViews[0]) {
      this._childViews[0].destroy();
      this._childViews[0] = cv;
    }

    if (cv) {
      cv.set('_parentView', this);
      cv.set('templateData', this.get('templateData'));
      this._childViews[0] = cv;
    } else {
      this._childViews.clear();
    }

    if (this._scheduled) return;
    this._scheduled = true;
    this.set('_containedView', cv);
    Ember.run.schedule('render', this, this.updateChildView);
  },

  render(buffer) {
    const element = buffer.element();
    const dom = buffer.dom;

    this._childViewsMorph = dom.appendMorph(element);
  },

  updateChildView() {
    this._scheduled = false;
    if (!this._elementCreated || this.isDestroying || this.isDestroyed) { return; }

    const childView = this._containedView;
    if (childView && !childView._elementCreated) {
      this._renderer.renderTree(childView, this, 0);
    }
  },

  /**
    Triggers the set up for rendering a view that is cloaked.

    @method uncloak
  */
  uncloak() {
    const state = this._state || this.state;
    if (state !== 'inDOM' && state !== 'preRender') { return; }

    if (!this._containedView) {
      const model = this.get('content'),
          container = this.get('container');

      let controller;

      // Wire up the itemController if necessary
      const controllerName = this.get('cloaksController');
      if (controllerName) {
        const controllerFullName = 'controller:' + controllerName;
        let factory = container.lookupFactory(controllerFullName);

        // let ember generate controller if needed
        if (!factory) {
          factory = Ember.generateControllerFactory(container, controllerName, model);

          // inform developer about typo
          Ember.Logger.warn('ember-cloaking: can\'t lookup controller by name "' + controllerFullName + '".');
          Ember.Logger.warn('ember-cloaking: using ' + factory.toString() + '.');
        }

        const parentController = this.get('controller');
        controller = factory.create({ model, parentController, target: parentController });
      }

      const createArgs = {},
          target = controller || model;

      if (this.get('preservesContext')) {
        createArgs.content = target;
      } else {
        createArgs.context = target;
      }
      if (controller) { createArgs.controller = controller; }
      this.setProperties({
        style: null,
        loading: false
      });

      this.setContainedView(this.createChildView(this.get('cloaks'), createArgs));
    }
  },

  /**
    Removes the view from the DOM and tears down all observers.

    @method cloak
  */
  cloak() {
    const self = this;

    if (this._containedView && (this._state || this.state) === 'inDOM') {
      const style = 'height: ' + this.$().height() + 'px;';
      this.set('style', style);
      this.$().prop('style', style);


      // We need to remove the container after the height of the element has taken
      // effect.
      Ember.run.schedule('afterRender', function() {
        self.setContainedView(null);
      });
    }
  },

  _setHeights: function(){
    if (!this._containedView) {
      // setting default height
      // but do not touch if height already defined
      if(!this.$().height()){
        let defaultHeight = 100;
        if(this.get('defaultHeight')) {
          defaultHeight = this.get('defaultHeight');
        }

        this.$().css('height', defaultHeight);
      }
    }
   }.on('didInsertElement')
});

