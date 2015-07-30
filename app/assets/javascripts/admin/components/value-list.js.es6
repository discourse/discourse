export default Ember.Component.extend({
  classNameBindings: [':value-list'],

  _enableSorting: function() {
    const self = this;
    const placeholder = document.createElement("div");
    placeholder.className = "placeholder";

    let dragging = null;
    let over = null;
    let nodePlacement;

    this.$().on('dragstart.discourse', '.values .value', function(e) {
      dragging = e.currentTarget;
      e.dataTransfer.effectAllowed = 'move';
      e.dataTransfer.setData("text/html", e.currentTarget);
    });

    this.$().on('dragend.discourse', '.values .value', function() {
      Ember.run(function() {
        dragging.parentNode.removeChild(placeholder);
        dragging.style.display = 'block';

        // Update data
        const from = Number(dragging.dataset.index);
        let to = Number(over.dataset.index);
        if (from < to) to--;
        if (nodePlacement === "after") to++;

        const collection = self.get('collection');
        const fromObj = collection.objectAt(from);
        collection.replace(from, 1);
        collection.replace(to, 0, [fromObj]);
        self._saveValues();
      });
      return false;
    });

    this.$().on('dragover.discourse', '.values', function(e) {
      e.preventDefault();
      dragging.style.display = 'none';
      if (e.target.className === "placeholder") { return; }
      over = e.target;

      const relY = e.originalEvent.clientY - over.offsetTop;
      const height = over.offsetHeight / 2;
      const parent = e.target.parentNode;

      if (relY > height) {
        nodePlacement = "after";
        parent.insertBefore(placeholder, e.target.nextElementSibling);
      } else if(relY < height) {
        nodePlacement = "before";
        parent.insertBefore(placeholder, e.target);
      }
    });
  }.on('didInsertElement'),

  _removeSorting: function() {
    this.$().off('dragover.discourse').off('dragend.discourse').off('dragstart.discourse');
  }.on('willDestroyElement'),

  _setupCollection: function() {
    const values = this.get('values');
    if (this.get('inputType') === "array") {
      this.set('collection', values || []);
    } else {
      this.set('collection', (values && values.length) ? values.split("\n") : []);
    }
  }.on('init').observes('values'),

  _saveValues: function() {
    if (this.get('inputType') === "array") {
      this.set('values', this.get('collection'));
    } else {
      this.set('values', this.get('collection').join("\n"));
    }
  },

  inputInvalid: Ember.computed.empty('newValue'),

  keyDown(e) {
    if (e.keyCode === 13) {
      this.send('addValue');
    }
  },

  actions: {
    addValue() {
      if (this.get('inputInvalid')) { return; }

      this.get('collection').addObject(this.get('newValue'));
      this.set('newValue', '');

      this._saveValues();
    },

    removeValue(value) {
      const collection = this.get('collection');
      collection.removeObject(value);
      this._saveValues();
    }
  }
});
