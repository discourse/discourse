import { hash } from "@ember/helper";
import { eq } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import PluginOutlet from "./plugin-outlet";

const ConditionalLoadingSpinner = <template>
  <PluginOutlet
    @name="conditional-loading-spinner"
    @defaultGlimmer={{true}}
    @outletArgs={{hash condition=@condition size=@size}}
  >
    <div
      class={{concatClass
        "loading-container"
        (if @condition "visible")
        (if (eq @size "small") "inline-spinner")
      }}
      ...attributes
    >
      {{#if @condition}}
        <div class="spinner {{@size}}"></div>
      {{else}}
        {{yield}}
      {{/if}}
    </div>
  </PluginOutlet>
</template>;

export default ConditionalLoadingSpinner;
