import getURL from "discourse-common/lib/get-url";
import { bind } from "discourse-common/utils/decorators";
import showModal from "discourse/lib/show-modal";
import ChatMessageFlag from "discourse/plugins/chat/discourse/lib/chat-message-flag";
import Bookmark from "discourse/models/bookmark";
import { openBookmarkModal } from "discourse/controllers/bookmark";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { isTesting } from "discourse-common/config/environment";
import { clipboardCopy } from "discourse/lib/utilities";
import ChatMessageReaction, {
  REACTIONS,
} from "discourse/plugins/chat/discourse/models/chat-message-reaction";
import { getOwner, setOwner } from "@ember/application";
import { tracked } from "@glimmer/tracking";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { MESSAGE_CONTEXT_THREAD } from "discourse/plugins/chat/discourse/components/chat-message";
import I18n from "I18n";

export default class ChatChannelDOM {}
