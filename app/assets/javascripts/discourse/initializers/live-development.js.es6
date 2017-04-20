import DiscourseURL from 'discourse/lib/url';

export function refreshCSS(node, hash, newHref, options) {

  let $orig = $(node);

  if ($orig.data('reloading')) {

    if (options && options.force) {
      clearTimeout($orig.data('timeout'));
      $orig.data("copy").remove();
    } else {
      return;
    }
  }

  if (!$orig.data('orig')) {
    $orig.data('orig', node.href);
  }

  $orig.data('reloading', true);

  const orig = $(node).data('orig');

  let reloaded = $orig.clone(true);
  if (hash) {
    reloaded[0].href = orig + (orig.indexOf('?') >= 0 ? "&hash=" : "?hash=") + hash;
  } else {
    reloaded[0].href = newHref;
  }

  $orig.after(reloaded);

  let timeout = setTimeout(()=>{
    $orig.remove();
    reloaded.data('reloading', false);
  }, 2000);

  $orig.data("timeout", timeout);
  $orig.data("copy", reloaded);
}

//  Use the message bus for live reloading of components for faster development.
export default {
  name: "live-development",
  initialize(container) {
    const messageBus = container.lookup('message-bus:main');

    // subscribe to any site customizations that are loaded
    $('link.custom-css').each(function() {
      const split = this.href.split("/"),
          id = split[split.length - 1].split(".css")[0],
          self = this;

      return messageBus.subscribe("/file-change/" + id, function(data) {
        if (!$(self).data('orig')) {
          $(self).data('orig', self.href);
        }
        const orig = $(self).data('orig');

        self.href = orig.replace(/v=.*/, "v=" + data);
      });
    });

    // Custom header changes
    $('header.custom').each(function() {
      const header = $(this);
      return messageBus.subscribe("/header-change/" + $(this).data('key'), function(data) {
        return header.html(data);
      });
    });

    // Useful to export this for debugging purposes
    if (Discourse.Environment === 'development' && !Ember.testing) {
      window.DiscourseURL = DiscourseURL;
    }

    // Observe file changes
    messageBus.subscribe("/file-change", function(data) {
      if (Handlebars.compile && !Ember.TEMPLATES.empty) {
        // hbs notifications only happen in dev
        Ember.TEMPLATES.empty = Handlebars.compile("<div></div>");
      }
      _.each(data,function(me) {

        if (me === "refresh") {
          // Refresh if necessary
          document.location.reload(true);
        } else {
          $('link').each(function() {
            if (this.href.match(me.name) && (me.hash || me.new_href)) {
              refreshCSS(this, me.hash, me.new_href);
            }
          });
        }
      });
    });
  }
};
