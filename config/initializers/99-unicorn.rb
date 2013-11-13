if (oobgc=ENV['UNICORN_OOBGC_REQS'].to_i) > 0
   require 'unicorn/oob_gc'
   Rails.configuration.middleware.insert 0, Unicorn::OobGC, oobgc
end
