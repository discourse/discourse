import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";
import { i18n } from "discourse-i18n";
import UserInfoList from "../../../components/user-info-list";

export default <template>
  <h2 class="cakeday-header">{{@controller.title}}</h2>

  <DLoadMore @selector=".user-info" @action={{@controller.loadMore}}>
    <DConditionalLoadingSpinner @condition={{@controller.model.loading}}>
      <UserInfoList @users={{@controller.model}} @isBirthday={{true}}>
        {{i18n "birthdays.today.empty"}}
      </UserInfoList>
    </DConditionalLoadingSpinner>

    <DConditionalLoadingSpinner @condition={{@controller.model.loadingMore}} />
  </DLoadMore>
</template>
