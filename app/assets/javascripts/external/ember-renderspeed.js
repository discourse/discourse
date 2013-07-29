//
//  ember-renderspeed
//
//  Include this script if you want to instrument your rendering speed in your Ember
//  applications.
//
//  https://github.com/eviltrout/ember-renderspeed
//
(function () {

  /**
    Used for assembling a tree of render calls so they can be grouped and displayed
    nicely afterwards.

    @class ProfileNode
  **/
  var ProfileNode = Ember.Object.extend({

    init: function() {
      this.set('children', []);
    },

    /**
      A string description of this node. If we have a template name we display that
      too.

      @property description
    **/
    description: function() {
      var result = "Rendered ";
      if (this.get('payload.template')) {
        result += "'" + this.get('payload.template') + "' ";
      }

      if (this.get('payload.object')) {
        result += this.get('payload.object').toString() + " ";
      }
      result += (Math.round(this.get('time') * 100) / 100).toString() + "ms";
      return result;
    }.property('time', 'payload.template', 'payload.object'),

    time: function() {
      return this.get('end') - this.get('start');
    }.property('start', 'end'),

    /**
      Adds a child node underneath this node. It also creates a reference between
      the child and the parent.

      @method addChild
      @param {ProfileNode} node the node we want as a child
    **/
    addChild: function(node) {
      node.set('parent', this);
      this.get('children').pushObject(node);
    },

    /**
      Logs this node and any children to the developer console, grouping appropriately
      for easy drilling down.

      @method log
    **/
    log: function() {
      if ((!console) || (!console.groupCollapsed)) { return; }

      // We don't care about really fast renders
      if (this.get('time') < 1) { return; }

      console.groupCollapsed(this.get('description'));
      this.get('children').forEach(function (c) {
        c.log();
      });
      console.groupEnd();
    }
  });


  // Set up our instrumentation of Ember below
  Ember.subscribe("render", {
    depth: null,

    before: function(name, timestamp, payload) {
      var node = ProfileNode.create({start: timestamp, payload: payload});

      if (this.depth) { this.depth.addChild(node); }
      this.depth = node;

      return node;
    },

    after: function(name, timestamp, payload, profileNode) {
      this.depth = profileNode.get('parent');
      profileNode.set('end', timestamp);

      if (!this.depth) {
        profileNode.log();
      }
    }
  });

})();

