import Component from "@glimmer/component";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import EmojiUploader from "discourse/admin/components/emoji-uploader";
import BackButton from "discourse/components/back-button";

export default class AdminConfigAreasEmojisNew extends Component {
  @service router;
  @service currentUser;
  @service adminEmojis;

  get emojiGroups() {
    return this.adminEmojis.emojiGroups;
  }

  @action
  emojiUploaded(emoji, group) {
    emoji.url += "?t=" + new Date().getTime();
    emoji.group = group;
    emoji.created_by = this.currentUser.username;
    this.adminEmojis.emojis = [
      ...this.adminEmojis.emojis,
      EmberObject.create(emoji),
    ];
    this.router.transitionTo("adminEmojis.index");
  }

  <template>
    <BackButton @label="admin.emoji.back" @route="adminEmojis.index" />
    <div class="admin-config-area">
      <div class="admin-config-area__primary-content admin-emoji-form">
        <AdminConfigAreaCard @heading="admin.emoji.add">
          <:content>
            <EmojiUploader
              @done={{this.emojiUploaded}}
              @emojiGroups={{this.emojiGroups}}
            />
          </:content>
        </AdminConfigAreaCard>
      </div>
    </div>
  </template>
}
