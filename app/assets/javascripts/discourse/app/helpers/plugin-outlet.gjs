import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import { connectorsExist } from "discourse/lib/plugin-connectors";
import rawRenderGlimmer from "discourse/lib/raw-render-glimmer";
import RawHandlebars from "discourse-common/lib/raw-handlebars";

const GlimmerPluginOutletWrapper = <template>
  {{~! no whitespace ~}}
  <PluginOutlet @name={{@data.name}} @outletArgs={{@data.outletArgs}} />
  {{~! no whitespace ~}}
</template>;

RawHandlebars.registerHelper("plugin-outlet", function (options) {
  const { name, tagName, outletArgs } = options.hash;

  if (!connectorsExist(name)) {
    return htmlSafe("");
  }

  return htmlSafe(
    rawRenderGlimmer(
      this,
      `${tagName || "span"}.hbr-ember-outlet`,
      GlimmerPluginOutletWrapper,
      { name, outletArgs }
    )
  );
});
