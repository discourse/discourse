//
//  ember-renderspeed
//
//  Include this script if you want to instrument your rendering speed in your Ember
//  applications.
//
//  https://github.com/eviltrout/ember-renderspeed
//
if ((typeof console !== 'undefined') && console.groupCollapsed) {

  (function () {

    /**
      Used for assembling a tree of render calls so they can be grouped and displayed
      nicely afterwards.

      @class ProfileNode
    **/
    var ProfileNode = function(start, payload) {
      this.start = start;
      this.payload = payload;
      this.children = [];
    };

    /**
      Adds a child node underneath this node. It also creates a reference between
      the child and the parent.

      @method addChild
      @param {ProfileNode} node the node we want as a child
    **/
    ProfileNode.prototype.addChild = function(node) {
      node.parent = this;
      this.children.push(node);
    };

    /**
      Logs this node and any children to the developer console, grouping appropriately
      for easy drilling down.

      @method log
    **/
    ProfileNode.prototype.log = function(type) {
      var time = this.end - this.start;
      if (time < 1) { return; }

      var description = "";
      if (this.payload) {
        if (this.payload.template) {
          description += "'" + this.payload.template + "' ";
        }

        if (this.payload.object) {
          description += this.payload.object.toString() + " ";
        }
      }
      description += (Math.round(time * 100) / 100).toString() + "ms";

      console.groupCollapsed(type + ": " + description);
      this.children.forEach(function (c) {
        c.log(type);
      });
      console.groupEnd();
    }

    // Set up our instrumentation of Ember below
    Ember.subscribe("render", {
      depth: null,

      before: function(name, timestamp, payload) {
        var node = new ProfileNode(timestamp, payload);
        if (this.depth) { this.depth.addChild(node); }
        this.depth = node;

        return node;
      },

      after: function(name, timestamp, payload, profileNode) {
        this.depth = profileNode.parent;
        profileNode.end = timestamp;

        if (!this.depth) {
          profileNode.log("Render");
        }
      }
    });

  })();

}