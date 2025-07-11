import { hbs } from "ember-cli-htmlbars";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import { withPluginApi } from "discourse/lib/plugin-api";
import Site from "discourse/models/site";
import { registerWidgetShim } from "discourse/widgets/render-glimmer";
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
      <div class="ad-connector">
        <PostBottomAd @model={{@post}} />
      </div>
    </template>
  );

  withSilencedDeprecations("discourse.post-stream-widget-overrides", () =>
    customizeWidgetPost(api)
  );
}

function customizeWidgetPost(api) {
  registerWidgetShim(
    "after-post-ad",
    "div.ad-connector",
    hbs`<PostBottomAd @model={{@data}} />`
  );

  api.decorateWidget("post:after", (helper) => {
    return helper.attach("after-post-ad", helper.widget.model);
  });
}
