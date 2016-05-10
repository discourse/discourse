import { htmlHelper } from 'discourse/lib/helpers';

export default htmlHelper(str => Discourse.Utilities.escapeExpression(str).replace(/\n/g, "<br>"));
