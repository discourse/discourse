import Component from "@ember/component";
import { gte } from "@ember/object/computed";

export default class ReviewableConversationPost extends Component {
  @gte("index", 1) showUsername;
}
