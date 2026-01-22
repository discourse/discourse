declare module 'types/-private' {
	import { ModifierLike } from '@glint/template';

	export type RenderModifier<El extends Element, Args extends Array<any>> = InstanceType<
	  ModifierLike<{
	    Element: El;
	    Args: {
	      Positional: [callback: (element: El, args: Args) => unknown, ...callbackArgs: Args];
	    };
	  }>
	>;

}
declare module 'types/modifiers/did-insert' {
	import { RenderModifier } from 'types/-private'; const didInsert: abstract new <
	  El extends Element,
	  Args extends Array<any>
	>() => RenderModifier<El, Args>;

	export default didInsert;

}
declare module 'types/modifiers/did-update' {
	import { RenderModifier } from 'types/-private'; const didUpdate: abstract new <
	  El extends Element,
	  Args extends Array<any>
	>() => RenderModifier<El, Args>;

	export default didUpdate;

}
declare module 'types/modifiers/will-destroy' {
	import { RenderModifier } from 'types/-private'; const willDestroy: abstract new <
	  El extends Element,
	  Args extends Array<any>
	>() => RenderModifier<El, Args>;

	export default willDestroy;

}
declare module 'types/template-registry' {
	import type didInsert from 'types/modifiers/did-insert';
	import type didUpdate from 'types/modifiers/did-update';
	import type willDestroy from 'types/modifiers/will-destroy';

	export default interface RenderModifiersRegistry {
	  'did-insert': typeof didInsert;
	  'did-update': typeof didUpdate;
	  'will-destroy': typeof willDestroy;
	}

}
