require 'benchmark/ips'
require File.expand_path('../../../../config/environment', __FILE__)

# Put pre conditions here
# Used db but it's OK in the most cases

# build the cache
SiteSetting.title = SecureRandom.hex
SiteSetting.default_locale = SiteSetting.default_locale == 'en' ? 'zh_CN' : 'en'
SiteSetting.refresh!

tests = [
  ["current cache", lambda do
    SiteSetting.title
    SiteSetting.enable_sso
  end
  ],
  ["change default locale with current cache refreshed", lambda do
    SiteSetting.default_locale = SiteSetting.default_locale == 'en' ? 'zh_CN' : 'en'
  end
  ],
  ["change site setting", lambda do
    SiteSetting.title = SecureRandom.hex
  end
  ],
]

Benchmark.ips do |x|
  tests.each do |test, proc|
    x.report(test, proc)
  end
end

# 2017-08-02 - Erick's Site Setting change

# Before
# Calculating -------------------------------------
# current cache    167.518k (±12.1%) i/s -    822.983k in   5.000478s
# change default locale with current cache refreshed
# 174.173  (±16.7%) i/s -    845.000  in   5.015281s
# change site setting    132.956  (±16.5%) i/s -    663.000  in   5.124766s

# After
# Calculating -------------------------------------
# current cache    167.170k (±12.2%) i/s -    824.688k in   5.022784s
# change default locale with current cache refreshed
# 79.876  (±16.3%) i/s -    392.000  in   5.067448s
# change site setting    129.085  (±13.2%) i/s -    636.000  in   5.032536s
