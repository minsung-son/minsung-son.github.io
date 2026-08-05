require 'date'

# Normalises article front matter (images, title, date, category, teaser, landing/hidden —
# see ARTICLE_MANUAL.md) so imperfect author input degrades to a logged fallback, never a break.
# High priority so article_ids.rb sorts the already-normalised dates.
Jekyll::Hooks.register :site, :post_read, priority: :high do |site|
  collection = site.collections['articles']
  next if collection.nil?

  collection.docs.each do |doc|
    dir  = File.dirname(doc.path)
    warn = ->(msg) { Jekyll.logger.warn 'Articles:', "#{doc.relative_path}: #{msg}" }

    # _articles/<category>/<article-folder>/index.md
    parts      = doc.relative_path.split('/')
    folder_cat = parts.length >= 4 ? parts[1].downcase : nil
    folder     = File.basename(dir)

    media  = ArticleBody.media_files(dir)
    images = media.grep(ArticleBody::IMAGE_EXT)
                  .sort_by { |f| [f.scan(/\d+/).map(&:to_i), ArticleBody.norm(f)] }
    doc.data['images'] = images

    title = doc.data['title'].to_s.strip
    if title.empty?
      title = folder.sub(/\A[A-Za-z]-/, '')
      warn.call("missing title — using folder name \"#{title}\"")
    end
    doc.data['title'] = title

    raw_date = doc.data['date']
    article_date = case raw_date
                   when Time then raw_date.to_date
                   when Date then raw_date
                   when String
                     begin
                       Date.iso8601(raw_date.strip)
                     rescue ArgumentError
                       nil
                     end
                   end
    if article_date.nil?
      article_date = File.mtime(doc.path).to_date
      detail = raw_date.nil? || raw_date.to_s.strip.empty? ? 'missing date' : "unreadable date #{raw_date.inspect}"
      warn.call("#{detail} — using file modified date #{article_date}")
    end
    doc.data['date'] = article_date

    # Category comes solely from the folder; any `category:` front matter line is ignored
    doc.data['category'] = folder_cat if folder_cat

    teaser   = doc.data['teaser'].to_s.strip
    resolved = teaser.empty? ? nil : ArticleBody.resolve_file(teaser, images)
    if resolved.nil?
      warn.call("teaser \"#{teaser}\" was not found — using first image") unless teaser.empty?
      resolved = images.first
    end
    doc.data['teaser'] = resolved

    %w[landing hidden].each do |key|
      value = doc.data[key]
      next if value == true || value == false

      doc.data[key] = %w[true yes y 1 on].include?(value.to_s.strip.downcase)
    end
  end
end
