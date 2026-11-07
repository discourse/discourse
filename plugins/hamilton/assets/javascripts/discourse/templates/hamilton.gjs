import { LinkTo } from "@ember/routing";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="hamilton">
    <nav aria-label={{i18n "hamilton.title"}} class="hamilton__nav">
      <LinkTo @route="hamilton.index">{{i18n "hamilton.title"}}</LinkTo>
      <LinkTo @route="hamilton.docs.index">{{i18n "hamilton.docs"}}</LinkTo>
    </nav>
    {{outlet}}
  </div>
</template>
