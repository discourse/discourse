import { withPluginApi } from "discourse/lib/plugin-api";
import Site from "discourse/models/site";
import NestedRootAd from "../components/nested-root-ad.gjs";
import PostBottomAd from "../components/post-bottom-ad.gjs";

export default {
  name: "initialize-ad-plugin",
  initialize(container) {
    withPluginApi((api) => {
      customizePost(api);
    });

    const messageBus = container.lookup("service:message-bus");
    const currentUser = container.lookup("service:current-user");

    const houseAdsChannel = currentUser
      ? "/site/house-creatives/logged-in"
      : "/site/house-creatives/anonymous";

    messageBus.subscribe(houseAdsChannel, function (houseAdsSettings) {
      Site.currentProp("house_creatives", houseAdsSettings);
    });

    const dfpConfig = container.lookup("service:dfp-config");
    messageBus.subscribe(
      "/site/dfp-category-settings/changed",
      function (payload) {
        dfpConfig.onSignal(payload);
      }
    );
  },
};

function customizePost(api) {
  api.renderAfterWrapperOutlet(
    "post-article",
    <template>
      {{#unless @nestedReplyView}}
        <div class="ad-connector">
          <PostBottomAd @model={{@post}} />
        </div>
      {{/unless}}
    </template>
  );

  api.renderInOutlet("nested-roots-between", NestedRootAd);
}
