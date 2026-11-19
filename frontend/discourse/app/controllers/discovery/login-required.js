import Controller, { inject as controller } from "@ember/controller";
import { service } from "@ember/service";

export default class LoginRequiredController extends Controller {
  // eslint-disable-next-line discourse/no-unused-services
  @service login; // used in the route template
  @controller application;
}
