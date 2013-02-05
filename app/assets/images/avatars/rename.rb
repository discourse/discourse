all_files = [Dir["*.jpg"] + Dir["*.jpeg"]].flatten
all_files.each do |f|
  File.rename(f, "#{rand(2**256).to_s(36)[0..7]}.jpg")
end

all_files = [Dir["*.jpg"] + Dir["*.jpeg"]].flatten
all_files.each_with_index do |f, i|
  File.rename(f, "#{i}.jpg")
end
