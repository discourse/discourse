import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatIndexRoute extends DiscourseRoute {
  @service chat;

  beforeModel() {
    if (this.site.mobileView) {
      return; // Always want the channel index on mobile.
    }

    // We are on desktop. Check for a channel to enter and transition if so.
    // Otherwise, `setupController` will fetch all available
    return this.chat.getIdealFirstChannelIdAndTitle().then((channelInfo) => {
      if (channelInfo) {
        return this.chat.getChannelBy("id", channelInfo.id).then((c) => {
          this.chat.openChannel(c);
          return;
        });
      } else {
        return this.transitionTo("chat.browse");
      }
    });
  }

  model() {
    if (this.site.mobileView) {
      return this.chat.getChannels().then((channels) => {
        if (
          channels.publicChannels.length ||
          channels.directMessageChannels.length
        ) {
          return channels;
        }
      });
    }
  }
}
