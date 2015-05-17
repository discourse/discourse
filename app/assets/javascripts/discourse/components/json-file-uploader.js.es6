
export default Em.Component.extend({
  fileInput: null,
  loading: false,
  expectedRootObjectName: null,

  classNames: ['json-uploader'],

  _initialize: function() {
    const $this = this.$();
    const self = this;

    const $fileInput = $this.find('#js-file-input');
    this.set('fileInput', $fileInput[0]);

    $fileInput.on('change', function() {
      self.fileSelected(this.files);
    });

    const $fileSelect = $this.find('.fileSelect');

    $fileSelect.on('dragover dragenter', function(e) {
      if (e.preventDefault) e.preventDefault();
      return false;
    });
    $fileSelect.on('drop', function(e) {
      if (e.preventDefault) e.preventDefault();

      self.fileSelected(e.dataTransfer.files);
      return false;
    });

  }.on('didInsertElement'),

  setReady: function() {
    let parsed;
    try {
      parsed = JSON.parse(this.get('value'));
    } catch (e) {
      this.set('ready', false);
      return;
    }

    const rootObject = parsed[this.get('expectedRootObjectName')];

    if (rootObject !== null && rootObject !== undefined) {
      this.set('ready', true);
    } else {
      this.set('ready', false);
    }
  }.observes('destination', 'expectedRootObjectName'),

  actions: {
    selectFile: function() {
      const $fileInput = $(this.get('fileInput'));
      $fileInput.click();
    }
  },

  fileSelected(fileList) {
    const self = this;
    const numFiles = fileList.length;
    const firstFile = fileList[0];

    this.set('loading', true);

    let reader = new FileReader();
    reader.onload = function(evt) {
      self.set('value', evt.target.result);
      self.set('loading', false);
    };

    reader.readAsText(firstFile);
  }

});
