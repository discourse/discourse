import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";
import UserInfoList from "../../../components/user-info-list";

export default <template>
  <LoadMore @selector=".user-info" @action={{@controller.loadMore}}>
    <div class="cakeday-months">
      <h2 class="cakeday-header">{{i18n "birthdays.month.title"}}</h2>
      <ComboBox
        @content={{@controller.months}}
        @value={{@controller.month}}
        @valueAttribute="value"
        @none="cakeday.none"
      />
    </div>

    <ConditionalLoadingSpinner @condition={{@controller.model.loading}}>
      <UserInfoList @users={{@controller.model}} @isBirthday={{true}}>
        {{i18n "birthdays.month.empty"}}
      </UserInfoList>
    </ConditionalLoadingSpinner>

    <ConditionalLoadingSpinner @condition={{@controller.model.loadingMore}} />
  </LoadMore>
</template>
