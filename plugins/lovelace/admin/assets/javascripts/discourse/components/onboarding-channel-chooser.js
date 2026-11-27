import { classNames } from "@ember-decorators/component";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ComboBox from "discourse/select-kit/components/combo-box";
import { selectKitOptions } from "discourse/select-kit/components/select-kit";

@classNames("lovelace-channel-chooser")
@selectKitOptions({
  filterable: true,
  clearable: true,
  shouldDisplayIcon: true,
})
export default class OnboardingChannelChooser extends ComboBox {
  nameProperty = "title";

  modifySelection(channel) {
    return channel?.id ? { ...channel, icon: "d-chat" } : channel;
  }

  async search(filter) {
    try {
      const result = await ajax("/chat/api/channels", {
        data: { filter, status: "open" },
      });
      return result.channels.map((channel) => ({ ...channel, icon: "d-chat" }));
    } catch (error) {
      popupAjaxError(error);
      return [];
    }
  }
}
