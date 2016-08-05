import { htmlHelper } from 'discourse/lib/helpers';
import { escapeExpression } from 'discourse/lib/utilities';

export default htmlHelper(str => escapeExpression(str).replace(/\n/g, "<br>"));
