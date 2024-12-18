import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class Posts extends DiscourseRoute {
  @service router;
}
