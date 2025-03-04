import { concat } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import PluginOutlet from "discourse/components/plugin-outlet";
import WatchRead from "discourse/components/watch-read";
import bodyClass from "discourse/helpers/body-class";
import htmlSafe from "discourse/helpers/html-safe";
export default RouteTemplate(<template>
  {{bodyClass (concat "static-" @controller.model.path)}}

  <section class="container">
    <WatchRead>
      <div class="contents clearfix body-page">
        <PluginOutlet @name="above-static" />
        {{htmlSafe @controller.model.html}}
        <PluginOutlet @name="below-static" />
      </div>
    </WatchRead>
  </section>
</template>);
