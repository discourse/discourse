import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import { i18n } from "discourse-i18n";
import UserInfoList from "../../../components/user-info-list";

export default RouteTemplate(
  <template>
    <h2 class="cakeday-header">{{@controller.title}}</h2>

    <LoadMore @selector=".user-info" @action={{@controller.loadMore}}>
      <ConditionalLoadingSpinner @condition={{@controller.model.loading}}>
        <UserInfoList @users={{@controller.model}} @isBirthday={{true}}>
          {{i18n "birthdays.upcoming.empty"}}
        </UserInfoList>
      </ConditionalLoadingSpinner>

      <ConditionalLoadingSpinner @condition={{@controller.model.loadingMore}} />
    </LoadMore>
  </template>
);
