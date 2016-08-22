import { cook } from 'discourse/lib/text';
import { registerUnbound } from 'discourse/lib/helpers';

registerUnbound('cook-text', cook);
