/**
  The topic jumper that shows when you click on the progress bar.

  @class TopicJumperComponent
  @extends Ember.Component
  @namespace Discourse
  @module Discourse
**/

Discourse.TopicJumperComponent = Ember.Component.extend({

  init: function() {
    this._super();

    this.set('hidden', true);
    this.set('hideCount', 2);

    var self = this;

    Em.run.schedule('afterRender', function() {
      var $text = $("#jumper-text"),
          $slider = $("#jumper-slider");

      self.set('$textElement', $text);
      self.set('$sliderElement', $slider);

      // Set up listeners (can't get element before render)

      $text.on("input", Discourse.debounce(function() {
        var value = parseInt($(this).val());

        if (isNaN(value)) {
          self.set('badNumber', true);
        } else {
          self.move(value);
        }
      }, 500));

      var bounce2 = Discourse.debounce(function() {
        self.move(self.get('$sliderElement').val());
      }, 250);

      $slider.on("input", Discourse.debounce(function() {
        self.setNumber($(this).val());
        bounce2();
      }, 50));
      $slider.on("change", Discourse.debounce(function() {
        self.setNumber($(this).val());
        bounce2();
      }, 50));

      self.setNumber();
    });
  },

  positionObserver: Discourse.debounce(function() {
    this.setNumber();

    // Hide the jumper if they scroll around too much without using it
    var count = this.get('hideCount');
    this.set('hideCount', --count);
    if (count <= 0) {
      this.set('hidden', true);
    }
  }, 100).observes('topic.progressPosition'),

  setNumber: function(position) {
    if (position === undefined) {
      position = this.get('topic.progressPosition');
    }
    this.set('badNumber', false);
    this.get('$textElement').val(position);
    this.get('$sliderElement').val(position);
  },

  move: function(position) {
    var topic = this.get('topic.model');
    if (position > topic.get('highest_post_number')) {
      position = topic.get('highest_post_number');
    }

    this.setNumber(position);
    this.set('hideCount', 3);
    Discourse.URL.routeTo(topic.urlForPostNumber(position));
  },

  actions: {
    openJumper: function() {
      this.set('hidden', !this.get('hidden'));
      if (!this.get('hidden')) {
        // if now visible
        this.setNumber();
        this.set('hideCount', 2);
      }
    }
  }
});
