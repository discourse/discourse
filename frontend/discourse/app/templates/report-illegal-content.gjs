import DsaNoticeForm from "discourse/components/dsa-notice-form";
import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";

export default <template>
  {{hideApplicationSidebar}}
  <DsaNoticeForm @contentUrl={{@controller.content_url}} />
</template>
