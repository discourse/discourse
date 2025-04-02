import Component from "@ember/component";
import { alias, equal } from "@ember/object/computed";
import { htmlSafe } from "@ember/template";
import discourseComputed from "discourse/lib/decorators";

export const NEW_TOPIC_SELECTION = "new_topic";
export const EXISTING_TOPIC_SELECTION = "existing_topic";
export const NEW_MESSAGE_SELECTION = "new_message";

export default class ChatToTopicSelector extends Component {
  newTopicSelection = NEW_TOPIC_SELECTION;
  existingTopicSelection = EXISTING_TOPIC_SELECTION;
  newMessageSelection = NEW_MESSAGE_SELECTION;
  selection = null;

  @equal("selection", NEW_TOPIC_SELECTION) newTopic;
  @equal("selection", EXISTING_TOPIC_SELECTION) existingTopic;
  @equal("selection", NEW_MESSAGE_SELECTION) newMessage;
  @alias("site.can_create_tag") canAddTags;
  @alias("site.can_tag_pms") canTagMessages;

  topicTitle = null;
  categoryId = null;
  tags = null;
  selectedTopicId = null;
  chatMessageIds = null;
  chatChannelId = null;

  @discourseComputed()
  newTopicInstruction() {
    return htmlSafe(this.instructionLabels[NEW_TOPIC_SELECTION]);
  }

  @discourseComputed()
  existingTopicInstruction() {
    return htmlSafe(this.instructionLabels[EXISTING_TOPIC_SELECTION]);
  }

  @discourseComputed()
  newMessageInstruction() {
    return htmlSafe(this.instructionLabels[NEW_MESSAGE_SELECTION]);
  }
}
