(function($) {
  $.fn.applyLocalDates = function(repeat) {
    function _formatTimezone(timezone) {
      return timezone.replace("_", " ").split("/");
    }

    function processElement($element, options) {
      repeat = repeat || true;

      if (this.timeout) {
        clearTimeout(this.timeout);
      }

      var relativeTime = moment.utc(options.date + " " + options.time, "YYYY-MM-DD HH:mm");

      if (options.recurring && relativeTime < moment().utc()) {
        var parts = options.recurring.split(".");
        var count = parseInt(parts[0], 10);
        var type = parts[1];
        var diff = moment().diff(relativeTime, type);
        var add = Math.ceil(diff + count);

        relativeTime = relativeTime.add(add, type);
      }

      var previews = options.timezones.split("|").map(function(timezone) {
        var dateTime = relativeTime.tz(timezone).format(options.format);
        var timezoneParts = _formatTimezone(timezone);

        if (dateTime.match(/TZ/)) {
          return dateTime.replace("TZ", timezoneParts.join(": "));
        } else {
          var output = timezoneParts[0];
          if (timezoneParts[1]) {
            output += " (" + timezoneParts[1] + ")";
          }
          output += " " + dateTime;
          return output;
        }
      });

      relativeTime = relativeTime.tz(moment.tz.guess()).format(options.format);

      var html = "<span>";
      html += "<i class='fa fa-globe d-icon d-icon-globe'></i>";
      html += relativeTime.replace("TZ", _formatTimezone(moment.tz.guess()).join(": "));
      html += "</span>";

      var joinedPreviews = previews.join("\n");

      $element
        .html(html)
        .attr("title", joinedPreviews)
        .attr("data-tooltip", joinedPreviews)
        .addClass("cooked");

      if (repeat) {
        this.timeout = setTimeout(function() {
          processElement($element, options);
        }, 10000);
      }
    }

    return this.each(function() {
      var $this = $(this);

      var options = {};
      options.format = $this.attr("data-format");
      options.date = $this.attr("data-date");
      options.time = $this.attr("data-time");
      options.recurring = $this.attr("data-recurring");
      options.timezones = $this.attr("data-timezones") || "Etc/UTC";

      processElement($this, options);
    });
  };
})(jQuery);
