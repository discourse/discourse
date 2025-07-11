import $ from "jquery";
import { escape } from "pretty-text/sanitizer";
import discourseDebounce from "discourse/lib/debounce";
import loadScript from "discourse/lib/load-script";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-graphviz",

  renderGraphs($containers) {
    $containers.each((_, container) => {
      const $container = $(container);

      // if the container content has not yet been replaced
      // do nothing
      if (!$container.find("svg").length) {
        this.renderGraph($container);
      }
    });
  },

  renderGraph($container) {
    const graphDefinition = $container.text().trim();
    const engine = $container.attr("data-engine");

    const $spinner = $("<div class='spinner tiny'></div>");
    $container.html($spinner);

    loadScript("/plugins/discourse-graphviz/javascripts/viz-3.0.1.js").then(
      () => {
        $container.removeClass("is-loading");

        try {
          /* global vizRenderStringSync */
          const svgChart = vizRenderStringSync(graphDefinition, {
            format: "svg",
            engine,
          });
          $container.html(svgChart);
        } catch (e) {
          const $error = $(
            `<div class='graph-error'>${escape(e.message)}</div>`
          );
          $container.html($error);
        }
      }
    );
  },

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    if (siteSettings.discourse_graphviz_enabled) {
      withPluginApi("0.8.22", (api) => {
        api.decorateCooked(
          ($elem) => {
            const $graphviz = $elem.find(".graphviz");
            if ($graphviz.length) {
              discourseDebounce(this, this.renderGraphs, $graphviz, 200);
            }
          },
          { id: "graphviz" }
        );
      });
    }
  },
};
