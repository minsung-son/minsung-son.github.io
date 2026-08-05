module Jekyll
  class CleanIndexUrls < Generator
    safe true
    priority :highest

    def generate(site)
      site.collections.each_value do |collection|
        next unless collection.write?
        collection.docs.each do |doc|
          next unless File.basename(doc.relative_path, ".*") == "index"

          rel    = doc.relative_path.sub(/\A_#{collection.label}\//, "")
          parent = File.dirname(rel)
          next if parent == "."

          doc.data["permalink"] = "/#{collection.label}/#{parent}/"
        end
      end
    end
  end
end
