import Ember from 'ember';

function samePosition(a, b) {
  return a && b && a.x === b.x && a.y === b.y;
}

function positionElement() {
  var element, position, _position;

  Ember.instrument('view.updateContext.positionElement', this, function() {
    element = this.element;
    position = this.position;
    _position = this._position;

    if (!position || !element) {
      return;
    }

    // // TODO: avoid needing this by avoiding unnecessary
    // // calls to this method in the first place
    if (samePosition(position, _position)) {
      return;
    }

    Ember.run.schedule('render', this, this._parentView.applyTransform, this, position.x, position.y);
    this._position = position;
  }, this);
}

export default Ember.Mixin.create({
  classNames: ['ember-list-item-view'],
  style: Ember.String.htmlSafe(''),
  attributeBindings: ['style'],
  _position: null,
  _positionElement: positionElement,

  positionElementWhenInserted: Ember.on('init', function(){
    this.one('didInsertElement', positionElement);
  }),

  updatePosition: function(position) {
    this.position = position;
    this._positionElement();
  }
});
