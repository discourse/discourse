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

      var relativeTime;
      if (options.timezone) {
        relativeTime = moment
          .tz(options.date + " " + options.time, options.timezone)
          .utc();
      } else {
        relativeTime = moment.utc(options.date + " " + options.time);
      }

      if (relativeTime < moment().utc()) {
        if (options.recurring) {
          var parts = options.recurring.split(".");
          var count = parseInt(parts[0], 10);
          var type = parts[1];
          var diff = moment().diff(relativeTime, type);
          var add = Math.ceil(diff + count);

          relativeTime = relativeTime.add(add, type);
        } else {
          $element.addClass("past");
        }
      }

      var previews = options.timezones.split("|").map(function(timezone) {
        var dateTime = relativeTime
          .tz(timezone)
          .format(options.format || "LLL");

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

      var displayTimezone = moment.tz.guess();
      var relativeTime = relativeTime.tz(displayTimezone);

      if (
        options.format !== "YYYY-MM-DD HH:mm:ss" &&
        relativeTime.isBetween(
          moment().subtract(1, "day"),
          moment().add(2, "day")
        )
      ) {
        relativeTime = relativeTime.calendar();
      } else {
        relativeTime = relativeTime.format(options.format);
      }

      var html = "<span>";
      html += "<i class='fa fa-globe d-icon d-icon-globe'></i>";
      html += "<span class='relative-time'></span>";
      html += "</span>";

      var joinedPreviews = previews.join("\n");

      var displayedTime = relativeTime.replace(
        "TZ",
        _formatTimezone(displayTimezone).join(": ")
      );

      $element
        .html(html)
        .attr("title", joinedPreviews)
        .attr("data-tooltip", joinedPreviews)
        .addClass("cooked-date")
        .find(".relative-time")
        .text(displayedTime);

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
      options.time = $this.attr("data-time") || "00:00:00";
      options.recurring = $this.attr("data-recurring");
      options.timezones = $this.attr("data-timezones");
      options.timezone = $this.attr("data-timezone");

      processElement($this, options);
    });
  };
})(jQuery);
