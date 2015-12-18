Dir["#{Rails.root}/lib/freedom_patches/*.rb"].each do |f|
  require(f)
end
