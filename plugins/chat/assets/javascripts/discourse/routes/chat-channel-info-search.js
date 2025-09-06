import DiscourseRoute from "discourse/routes/discourse";

export default class ChatChannelInfoSearchRoute extends DiscourseRoute {
  queryParams = { q: { replace: true } };
}
