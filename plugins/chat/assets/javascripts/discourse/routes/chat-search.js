import DiscourseRoute from "discourse/routes/discourse";

export default class ChatSearchRoute extends DiscourseRoute {
  queryParams = { q: { replace: true } };
}
