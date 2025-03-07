import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";

export default RouteTemplate(<template>
  <LinkTo @route="adminConfig.color-palettes-show" @model={{7}}>
    Hello
  </LinkTo>
</template>);
