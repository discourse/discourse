TranslationIO.configure do |config|
  config.api_key        = '5d908dafad774910ba5aeb881bb86eef'
  config.source_locale  = 'uk'
  config.target_locales = ['be-BY']

  # Uncomment this if you don't want to use gettext
  # config.disable_gettext = true

  # Uncomment this if you already use gettext or fast_gettext
  # config.locales_path = File.join('path', 'to', 'gettext_locale')

  # Find other useful usage information here:
  # https://github.com/translation/rails#readme
end
