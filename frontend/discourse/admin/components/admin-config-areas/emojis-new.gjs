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
    <BackButton @route="adminEmojis.index" @label="admin.emoji.back" />
    <div class="admin-config-area">
      <div class="admin-config-area__primary-content admin-emoji-form">
        <AdminConfigAreaCard @heading="admin.emoji.add">
          <:content>
            <EmojiUploader
              @emojiGroups={{this.emojiGroups}}
              @done={{this.emojiUploaded}}
            />
          </:content>
        </AdminConfigAreaCard>
      </div>
    </div>
  </template>
}
