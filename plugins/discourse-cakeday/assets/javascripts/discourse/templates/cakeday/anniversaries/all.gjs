import { fn } from "@ember/helper";
import ComboBox from "discourse/select-kit/components/combo-box";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";
import { i18n } from "discourse-i18n";
import UserInfoList from "../../../components/user-info-list.gjs";

function changeMonth(controller, month) {
  controller.set("month", month);
}

export default <template>
  <DLoadMore @action={{@controller.loadMore}} @selector=".user-info">
    <div class="cakeday-months">
      <h2 class="cakeday-header">{{i18n "anniversaries.month.title"}}</h2>
      <ComboBox
        @content={{@controller.months}}
        @none="cakeday.none"
        @onChange={{fn changeMonth @controller}}
        @value={{@controller.month}}
        @valueAttribute="value"
      />
    </div>

    <DConditionalLoadingSpinner @condition={{@controller.model.loading}}>
      <UserInfoList @users={{@controller.model}}>
        {{i18n "anniversaries.month.empty"}}
      </UserInfoList>
    </DConditionalLoadingSpinner>

    <DConditionalLoadingSpinner @condition={{@controller.model.loadingMore}} />
  </DLoadMore>
</template>
