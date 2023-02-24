import IncomingEmail from "admin/models/incoming-email";
import Modal from "discourse/controllers/modal";
import Post from "discourse/models/post";
import { equal } from "@ember/object/computed";

// This controller handles displaying of raw email
export default Modal.extend({
  rawEmail: "",
  textPart: "",
  htmlPart: "",

  tab: "raw",

  showRawEmail: equal("tab", "raw"),
  showTextPart: equal("tab", "text_part"),
  showHtmlPart: equal("tab", "html_part"),

  onShow() {
    this.send("displayRaw");
  },

  loadRawEmail(postId) {
    return Post.loadRawEmail(postId).then((result) =>
      this.setProperties({
        rawEmail: result.raw_email,
        textPart: result.text_part,
        htmlPart: result.html_part,
      })
    );
  },

  loadIncomingRawEmail(incomingEmailId) {
    return IncomingEmail.loadRawEmail(incomingEmailId).then((result) =>
      this.setProperties({
        rawEmail: result.raw_email,
        textPart: result.text_part,
        htmlPart: result.html_part,
      })
    );
  },

  actions: {
    displayRaw() {
      this.set("tab", "raw");
    },
    displayTextPart() {
      this.set("tab", "text_part");
    },
    displayHtmlPart() {
      this.set("tab", "html_part");
    },
  },
});
