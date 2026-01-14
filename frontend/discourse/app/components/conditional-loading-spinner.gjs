import concatClass from "discourse/helpers/concat-class";
import lazyHash from "discourse/helpers/lazy-hash";
import { eq } from "discourse/truth-helpers";
import PluginOutlet from "./plugin-outlet";

const ConditionalLoadingSpinner = <template>
  <PluginOutlet
    @name="conditional-loading-spinner"
    @defaultGlimmer={{true}}
    @outletArgs={{lazyHash condition=@condition size=@size}}
  >
    <div
      class={{concatClass
        "loading-container"
        (if @condition "visible")
        (if (eq @size "small") "inline-spinner")
      }}
      data-loading={{@condition}}
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
