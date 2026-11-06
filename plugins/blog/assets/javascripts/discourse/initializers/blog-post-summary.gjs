import { apiInitializer } from "discourse/lib/api";
import BlogPostSummary from "../components/blog-post-summary.gjs";

export default apiInitializer((api) => {
  api.addTrackedPostProperties("blog_article");
  api.renderInOutlet("post-content-cooked-html", BlogPostSummary);
});
