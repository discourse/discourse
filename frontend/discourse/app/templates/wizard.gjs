import SiteSkeleton from "discourse/components/site-skeleton";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";

export default <template>
  {{hideApplicationSidebar}}
  {{hideApplicationFooter}}
  <div id="wizard-main">
    <SiteSkeleton />

    {{outlet}}
  </div>
</template>
