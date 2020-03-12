import { equal } from "@ember/object/computed";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import Post from "discourse/models/post";
import IncomingEmail from "admin/models/incoming-email";

// This controller handles displaying of raw email
export default Controller.extend(ModalFunctionality, {
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
    return Post.loadRawEmail(postId).then(result =>
      this.setProperties({
        rawEmail: result.raw_email,
        textPart: result.text_part,
        htmlPart: result.html_part
      })
    );
  },

  loadIncomingRawEmail(incomingEmailId) {
    return IncomingEmail.loadRawEmail(incomingEmailId).then(result =>
      this.setProperties({
        rawEmail: result.raw_email,
        textPart: result.text_part,
        htmlPart: result.html_part
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
    }
  }
});
