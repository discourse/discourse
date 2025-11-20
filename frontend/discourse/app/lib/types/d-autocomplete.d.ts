/**
 * Type signature for autocomplete results component
 */
export interface AutocompleteResultsSignature {
  Args: {
    /** Array of autocomplete results */
    results: Array<unknown>;
    /** Currently selected index in the results list */
    selectedIndex: number;
    /** Callback function triggered when a result is selected */
    onSelect: (result: unknown, index: number, event: Event) => void;
    /** Optional callback function triggered after component renders */
    onRender?: (results: Array<unknown>) => void;
  };
}
