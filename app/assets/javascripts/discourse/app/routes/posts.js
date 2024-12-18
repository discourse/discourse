import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class Post extends DiscourseRoute {
  @service router;
}
