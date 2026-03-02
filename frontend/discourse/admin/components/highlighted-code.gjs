import HighlightedCode from "discourse/components/highlighted-code";
import deprecated from "discourse/lib/deprecated";

deprecated(
  'Importing HighlightedCode from "discourse/admin/components/highlighted-code" is deprecated. Use "discourse/components/highlighted-code" instead.',
  {
    id: "discourse.admin-highlighted-code-import",
    since: "2026.3.0",
    dropFrom: "2027.1.0",
  }
);

export default HighlightedCode;
