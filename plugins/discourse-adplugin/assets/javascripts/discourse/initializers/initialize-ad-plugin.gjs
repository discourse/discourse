import { withPluginApi } from "discourse/lib/plugin-api";
import Site from "discourse/models/site";
import NestedRootAd from "../components/nested-root-ad";
import PostBottomAd from "../components/post-bottom-ad";

export default {
  name: "initialize-ad-plugin",
  initialize(container) {
    withPluginApi((api) => {
      customizePost(api);
    });

    const messageBus = container.lookup("service:message-bus");
    const currentUser = container.lookup("service:current-user");

    const channel = currentUser
      ? "/site/house-creatives/logged-in"
      : "/site/house-creatives/anonymous";

    messageBus.subscribe(channel, function (houseAdsSettings) {
      Site.currentProp("house_creatives", houseAdsSettings);
    });
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
