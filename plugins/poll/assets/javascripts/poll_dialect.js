/*global md5 */

(function() {

  const DATA_PREFIX = "data-poll-";
  const DEFAULT_POLL_NAME = "poll";

  const WHITELISTED_ATTRIBUTES = ["type", "name", "min", "max", "step", "order", "color", "background", "status"];
  const WHITELISTED_STYLES = ["color", "background"];

  const ATTRIBUTES_REGEX = new RegExp("(" + WHITELISTED_ATTRIBUTES.join("|") + ")=[^\\s\\]]+", "g");

  Discourse.Dialect.replaceBlock({
    start: /\[poll([^\]]*)\]([\s\S]*)/igm,
    stop: /\[\/poll\]/igm,

    emitter: function(blockContents, matches) {
      var o, contents = [];

      // post-process inside block contents
      if (blockContents.length) {
        var self = this, b;

        var postProcess = function(bc) {
          if (typeof bc === "string" || bc instanceof String) {
            var processed = self.processInline(String(bc));
            if (processed.length) {
              contents.push(["p"].concat(processed));
            }
          } else {
            contents.push(bc);
          }
        };

        while ((b = blockContents.shift()) !== undefined) {
          this.processBlock(b, blockContents).forEach(postProcess);
        }
      }

      // default poll attributes
      var attributes = { "class": "poll" };
      attributes[DATA_PREFIX + "status"] = "open";
      attributes[DATA_PREFIX + "name"] = DEFAULT_POLL_NAME;

      // extract poll attributes
      (matches[1].match(ATTRIBUTES_REGEX) || []).forEach(function(m) {
        var attr = m.split("=");
        attributes[DATA_PREFIX + attr[0]] = attr[1];
      });

      // we might need these values later...
      var min = parseInt(attributes[DATA_PREFIX + "min"], 10),
          max = parseInt(attributes[DATA_PREFIX + "max"], 10),
          step = parseInt(attributes[DATA_PREFIX + "step"], 10);

      // generate the options when the type is "number"
      if (attributes[DATA_PREFIX + "type"] === "number") {
        // default values
        if (isNaN(min)) { min = 1; }
        if (isNaN(max)) { max = 10; }
        if (isNaN(step)) { step = 1; }
        // dynamically generate options
        contents.push(["bulletlist"]);
        for (o = min; o <= max; o += step) {
          contents[0].push(["listitem", String(o)]);
        }
      }

      // make sure the first child is a list with at least 1 option
      if (contents.length === 0 || contents[0].length <= 1 || (contents[0][0] !== "numberlist" && contents[0][0] !== "bulletlist")) {
        return ["div"].concat(contents);
      }

      // TODO: remove non whitelisted content

      // generate <li> styles (if any)
      var styles = [];
      WHITELISTED_STYLES.forEach(function(style) {
        if (attributes[DATA_PREFIX + style]) {
          styles.push(style + ":" + attributes[DATA_PREFIX + style]);
        }
      });

      var style = styles.join(";");

      // add option id (hash) + style
      for (o = 1; o < contents[0].length; o++) {
        // break as soon as the list is done
        if (contents[0][o][0] !== "listitem") { break; }

        var attr = {};
        // apply styles if any
        if (style.length > 0) { attr["style"] = style; }
        // compute md5 hash of the content of the option
        attr[DATA_PREFIX + "option-id"] = md5(JSON.stringify(contents[0][o].slice(1)));
        // store options attributes
        contents[0][o].splice(1, 0, attr);
      }

      // that's our poll!
      var pollContainer = ["div", { "class": "poll-container" }].concat(contents);
      var result = ["div", attributes, pollContainer];

      // add some information when type is "multiple"
      if (attributes[DATA_PREFIX + "type"] === "multiple") {
        var optionCount = contents[0].length - 1;

        // default values
        if (isNaN(min) || min < 1) { min = 1; }
        if (isNaN(max) || max > optionCount) { max = optionCount; }

        // add some help text
        var help;

        if (max > 0) {
          if (min === max) {
            if (min > 1) {
              help = I18n.t("poll.multiple.help.x_options", { count: min });
            }
          } else if (min > 1) {
            if (max < optionCount) {
              help = I18n.t("poll.multiple.help.between_min_and_max_options", { min: min, max: max });
            } else {
              help = I18n.t("poll.multiple.help.at_least_min_options", { count: min });
            }
          } else if (max <= optionCount) {
            help = I18n.t("poll.multiple.help.up_to_max_options", { count: max });
          }
        }

        if (help) { result.push(["p", help]); }

        // add "cast-votes" button
        result.push(["a", { "class": "button cast-votes", "title": I18n.t("poll.cast-votes.title") }, I18n.t("poll.cast-votes.label")]);
      }

      // add "toggle-results" button
      result.push(["a", { "class": "button toggle-results", "title": I18n.t("poll.show-results.title") }, I18n.t("poll.show-results.label")]);

      return result;
    }
  });

  Discourse.Markdown.whiteListTag("div", "class", "poll");
  Discourse.Markdown.whiteListTag("div", "class", "poll-container");
  Discourse.Markdown.whiteListTag("div", "data-*");

  Discourse.Markdown.whiteListTag("a", "class", /^button (cast-votes|toggle-results)/);

  Discourse.Markdown.whiteListTag("li", "data-*");
  Discourse.Markdown.whiteListTag("li", "style");

})();
