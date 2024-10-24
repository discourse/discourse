import Controller from "@ember/controller";
import { alias, gt } from "@ember/object/computed";

export default class AboutController extends Controller {
  @gt("siteSettings.faq_url.length", 0) faqOverridden;

  @alias("siteSettings.experimental_rename_faq_to_guidelines")
  renameFaqToGuidelines;
}
