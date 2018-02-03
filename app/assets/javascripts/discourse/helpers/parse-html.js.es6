/* global Tautologistics */
export default function parseHTML(rawHtml) {
  const builder = new Tautologistics.NodeHtmlParser.HtmlBuilder();
  const parser = new Tautologistics.NodeHtmlParser.Parser(builder);

  parser.parseComplete(rawHtml);
  return builder.dom;
}
