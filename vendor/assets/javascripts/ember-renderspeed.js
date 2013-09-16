//
//  ember-renderspeed
//
//  Include this script if you want to instrument your rendering speed in your Ember
//  applications.
//
//  https://github.com/eviltrout/ember-renderspeed
//
if ((typeof console !== 'undefined') && console.groupCollapsed && !window.QUnit) {

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
      Adds a child node underneath this node.

      @method addChild
      @param {ProfileNode} node the node we want as a child
    **/
    ProfileNode.prototype.addChild = function(node) {
      this.children.push(node);
    };

    /**
      Logs this node and any children to the developer console, grouping appropriately
      for easy drilling down.

      @method log
    **/
    ProfileNode.prototype.log = function(type) {
      var description = "";
      if (this.payload) {
        if (this.payload.template) {
          description += "'" + this.payload.template + "' ";
        }

        if (this.payload.object) {
          description += this.payload.object.toString() + " ";
        }
      }
      description += (Math.round(this.time * 100) / 100).toString() + "ms";

      if (this.children.length === 0) {
        console.log(type + ": " + description);
      } else {
        // render a collapsed group when there are children
        console.groupCollapsed(type + ": " + description);
        this.children.forEach(function (c) {
          c.log(type);
        });
        console.groupEnd();
      }
    }

    // Set up our instrumentation of Ember below
    Ember.subscribe("render", {
      depth: null,

      before: function(name, timestamp, payload) {
        var node = new ProfileNode(timestamp, payload);
        if (this.depth) { node.parent = this.depth; }
        this.depth = node;

        return node;
      },

      after: function(name, timestamp, payload, profileNode) {

        var parent = profileNode.parent;
        profileNode.time = (timestamp - profileNode.start);
        this.depth = profileNode.parent;

        if (profileNode.time < 1) { return; }

        if (this.depth) {
          this.depth.addChild(profileNode);
        } else {
          profileNode.log("Render");
        }
      }
    });

  })();

}
