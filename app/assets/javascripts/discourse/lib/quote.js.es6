export default {
  REGEXP: /\[quote=([^\]]*)\]((?:[\s\S](?!\[quote=[^\]]*\]))*?)\[\/quote\]/im,

  // Build the BBCode quote around the selected text
  build(post, contents, opts) {
    if (!post) {
      return "";
    }

    if (!contents) contents = "";

    const sansQuotes = contents.replace(this.REGEXP, "").trim();
    if (sansQuotes.length === 0) {
      return "";
    }

    // Strip the HTML from cooked
    const stripped = $("<div/>")
      .html(post.get("cooked"))
      .text();

    // Let's remove any non-word characters as a kind of hash.
    // Yes it's not accurate but it should work almost every time we need it to.
    // It would be unlikely that the user would quote another post that matches in exactly this way.
    const sameContent =
      stripped.replace(/\W/g, "") === contents.replace(/\W/g, "");

    const params = [
      post.get("username"),
      `post:${post.get("post_number")}`,
      `topic:${post.get("topic_id")}`
    ];

    opts = opts || {};

    if (opts["full"] || sameContent) params.push("full:true");

    return `[quote="${params.join(", ")}"]\n${
      opts["raw"] ? contents : sansQuotes
    }\n[/quote]\n\n`;
  }
};
