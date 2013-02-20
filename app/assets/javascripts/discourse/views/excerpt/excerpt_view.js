(function() {

  window.Discourse.ExcerptView = Ember.ContainerView.extend({
    classNames: ['excerpt-view'],
    classNameBindings: ['position', 'size'],
    childViews: ['closeView'],
    closeView: Ember.View.create({
      templateName: 'excerpt/close'
    }),
    /* Position the tooltip on the screen. There's probably a nicer way of coding this.
    */

    locationChanged: (function() {
      var loc;
      loc = this.get('location');
      return this.$().css(loc);
    }).observes('location'),
    visibleChanged: (function() {
      var _this = this;
      if (this.get('disabled')) {
        return;
      }
      if (this.get('visible')) {
        if (!this.get('opening')) {
          this.set('opening', true);
          this.set('closing', false);
          return jQuery('.excerpt-view').stop().fadeIn('fast', function() {
            return _this.set('opening', false);
          });
        }
      } else {
        if (!this.get('closing')) {
          this.set('closing', true);
          this.set('opening', false);
          return jQuery('.excerpt-view').stop().fadeOut('slow', function() {
            return _this.set('closing', false);
          });
        }
      }
    }).observes('visible'),
    urlChanged: (function() {
      var _this = this;
      if (this.get('url')) {
        this.set('visible', false);
        this.ajax = jQuery.ajax({
          url: "/excerpt",
          data: {
            url: this.get('url')
          },
          success: function(tooltip) {
            /* Make sure we still have a URL (if it changed, we no longer care about this request.)
            */

            var excerpt, instance, viewClass;
            if (!_this.get('url')) {
              return;
            }
            jQuery('.excerpt-view').stop().hide().css({
              opacity: 1
            });
            _this.set('closing', false);
            _this.set('location', _this.get('desiredLocation'));
            if (tooltip.created_at) {
              tooltip.created_at = Date.create(tooltip.created_at).relative();
            }
            viewClass = Discourse["Excerpt" + tooltip.type + "View"] || Em.View;
            excerpt = Em.Object.create(tooltip);
            excerpt.set('templateName', "excerpt/" + (tooltip.type.toLowerCase()));
            if (_this.get('contentsView')) {
              _this.removeObject(_this.get('contentsView'));
            }
            instance = viewClass.create(excerpt);
            instance.set("link", _this.hovering);
            _this.set('contentsView', instance);
            _this.addObject(instance);
            _this.set('excerpt', tooltip);
            return _this.set('visible', true);
          },
          error: function() {
            return _this.close();
          },
          complete: this.ajax = null
        });
      }
    }).observes('url'),
    close: function() {
      Em.run.cancel(this.closeTimer);
      Em.run.cancel(this.openTimer);
      this.set('url', null);
      this.set('visible', false);
      return false;
    },
    closeSoon: function() {
      var _this = this;
      this.closeTimer = Em.run.later(function() {
        return _this.close();
      }, 200);
    },
    disable: function() {
      this.set('disabled', true);
      Em.run.cancel(this.openTimer);
      Em.run.cancel(this.closeTimer);
      this.set('visible', false);
      if (this.ajax && this.ajax.abort) {
        this.ajax.abort();
      }
      return jQuery('.excerpt-view').stop().hide();
    },
    enable: function() {
      return this.set('disabled', false);
    }

    /* lets disable this puppy for now, it looks unprofessional    
    didInsertElement: function() {

      var _this = this;
      // We don't do hovering on touch devices
      if (Discourse.get('touch')) {
        return;
      }
      // If they dash into the excerpt, keep it open until they leave

      jQuery('.excerpt-view').on('mouseover', function(e) {
        return Em.run.cancel(_this.closeTimer);
      });
      jQuery('.excerpt-view').on('mouseleave', function(e) {
        return _this.closeSoon();
      });
      jQuery('#main').on('mouseover', '.excerptable', function(e) {
        var $target;
        $target = jQuery(e.currentTarget);
        _this.hovering = $target;
        // Make sure they're holding in place before we pop it up to mimimize annoyance
        Em.run.cancel(_this.openTimer);
        Em.run.cancel(_this.closeTimer);
        _this.openTimer = Em.run.later(function() {
          var bottomPosY, height, margin, pos, positionText, topPosY;
          pos = $target.offset();
          pos.top = pos.top - jQuery(window).scrollTop();
          positionText = $target.data('excerpt-position') || 'top';
          margin = 25;
          height = _this.$().height();
          topPosY = (pos.top - height) - margin;
          bottomPosY = pos.top + margin;
          // Switch to right if there's no room on top

          if (positionText === 'top') {
            if (topPosY < 10) {
              positionText = 'bottom';
            }
          }
          switch (positionText) {
            case 'right':
              pos.left = pos.left + $target.width() + margin;
              pos.top = pos.top - $target.height();
              break;
            case 'left':
              pos.left = pos.left - _this.$().width() - margin;
              pos.top = pos.top - $target.height();
              break;
            case 'top':
              pos.top = topPosY;
              break;
            case 'bottom':
              pos.top = bottomPosY;
          }
          if ((pos.left || 0) <= 0 && (pos.top || 0) <= 0) {
            // somehow, sometimes, we are trying to position stuff in weird spots, just skip it
            return;
          }
          _this.set('position', positionText);
          _this.set('desiredLocation', pos);
          _this.set('size', $target.data('excerpt-size'));
          return _this.set('url', $target.prop('href'));
        }, _this.get('visible') || _this.get('closing') ? 100 : Discourse.SiteSettings.popup_delay);
      });
      return jQuery('#main').on('mouseleave', '.excerptable', function(e) {
        Em.run.cancel(_this.openTimer);
        return _this.closeSoon();
      });      
    }
    */      
  });

}).call(this);
