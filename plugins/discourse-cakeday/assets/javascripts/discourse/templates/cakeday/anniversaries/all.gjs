import ComboBox from "discourse/select-kit/components/combo-box";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";
import { i18n } from "discourse-i18n";
import UserInfoList from "../../../components/user-info-list";

export default <template>
  <DLoadMore @selector=".user-info" @action={{@controller.loadMore}}>
    <div class="cakeday-months">
      <h2 class="cakeday-header">{{i18n "anniversaries.month.title"}}</h2>
      <ComboBox
        @content={{@controller.months}}
        @value={{@controller.month}}
        @valueAttribute="value"
        @none="cakeday.none"
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
