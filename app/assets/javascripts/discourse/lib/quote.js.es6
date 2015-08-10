export default {

  REGEXP: /\[quote=([^\]]*)\]((?:[\s\S](?!\[quote=[^\]]*\]))*?)\[\/quote\]/im,

  // Build the BBCode quote around the selected text
  build: function(post, contents, opts) {
    var contents_hashed, result, sansQuotes, stripped, stripped_hashed, tmp;
    var full = opts && opts["full"];
    var raw = opts && opts["raw"];

    if (!contents) contents = "";

    sansQuotes = contents.replace(this.REGEXP, '').trim();
    if (sansQuotes.length === 0) return "";

    // Escape the content of the quote
    sansQuotes = sansQuotes.replace(/</g, "&lt;")
                           .replace(/>/g, "&gt;");

    result = "[quote=\"" + post.get('username') + ", post:" + post.get('post_number') + ", topic:" + post.get('topic_id');

    /* Strip the HTML from cooked */
    tmp = document.createElement('div');
    tmp.innerHTML = post.get('cooked');
    stripped = tmp.textContent || tmp.innerText;

    /*
      Let's remove any non alphanumeric characters as a kind of hash. Yes it's
      not accurate but it should work almost every time we need it to. It would be unlikely
      that the user would quote another post that matches in exactly this way.
    */
    stripped_hashed = stripped.replace(/[^a-zA-Z0-9]/g, '');
    contents_hashed = contents.replace(/[^a-zA-Z0-9]/g, '');

    /* If the quote is the full message, attribute it as such */
    if (full || stripped_hashed === contents_hashed) result += ", full:true";
    result += "\"]\n" + (raw ? contents : sansQuotes) + "\n[/quote]\n\n";

    return result;
  }

};
