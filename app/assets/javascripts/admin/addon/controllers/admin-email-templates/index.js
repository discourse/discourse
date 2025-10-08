import Controller from "@ember/controller";
import { sort } from "@ember/object/computed";

export default class AdminEmailTemplatesIndexController extends Controller {
  titleSorting = ["title"];
  @sort("emailTemplates", "titleSorting") sortedTemplates;
}
