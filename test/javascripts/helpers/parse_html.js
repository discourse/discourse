function parseHTML(rawHtml) {
  var builder = new Tautologistics.NodeHtmlParser.HtmlBuilder(),
      parser = new Tautologistics.NodeHtmlParser.Parser(builder);

  parser.parseComplete(rawHtml);
  return builder.dom;
}