import Store from "discourse/models/store";
import RestAdapter from 'discourse/adapters/rest';

let _restAdapter;
export default function() {
  return Store.create({
    container: {
      lookup(type) {
        if (type === "adapter:rest") {
          _restAdapter = _restAdapter || RestAdapter.create({ container: this });
          return (_restAdapter);
        }
      },

      lookupFactory: function() { }
    }
  });
}

